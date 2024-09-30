// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

/**
 * @title Token Vesting Contract (Linear)
 * @dev This contract handles the vesting of ERC20 tokens for specific users. The vesting schedule is linear. 
 * Users are pre-signed into a merkle tree and the merkle root is used to verify the user's vesting schedule.
 * Pre-signature allows us to guarantee that the user's vesting schedule is valid and cannot be tampered with.
*/
contract TokenVestingLinear is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    /// @notice Schedule struct to store user's vesting schedule
    struct Schedule {
        uint256 allocation;           // Total allocation for the user
        uint256 claimed;              // Total amount claimed by the user
        uint64 startTimestamp;        // Vesting start time
        uint64 endTimestamp;          // Vesting end time
        uint8 initUnlockPercentage;   // Initial unlocked percentage of tokens
    }

    /**
     * @notice UserSchedule struct to store user's vesting schedule and their wallet address in bytes.
     * @dev User is in bytes to allow Solana address to be used along with Ethereum address.
    */
    struct UserSchedule {
        bytes32 user;
        Schedule schedule;
    }

    /// @notice Portal token contract
    IERC20 public token;

    /// @notice Address of the signer. Signer is used in cases where the user wants to delegate the vesting to another wallet (not one that is being vested).
    address public signerAddress;

    /// @notice Merkle root for the vesting schedule. This is used to preseed and verify the vesting schedule for a user.
    bytes32 public immutable root;
    
    
    /// @notice Mapping from user address to vesting details
    mapping(address => Schedule) public schedules;
    mapping(bytes32 => address) public primaryWalletBytesToAddress;

    /// @notice Event emitted when tokens are released
    event TokensReleased(address indexed user, uint256 amount);
    /// @notice Event emitted when a new vesting schedule is added (activated)
    event ScheduleSet(address indexed recepientAddress, bytes32 user);
    /// @notice Event emitted when a user's recepient wallet is updated
    event RecepientAddressUpdated(bytes32 indexed userAddressInBytes, address indexed currentRecepientWallet, address indexed newRecepientWallet);
    /// @notice Event emitted when the signer address is updated
    event SignerAddressSet(address signerAddress_);
    /// @notice Event emitted when the token address is updated (can only be set once)
    event TokenAddressUpdated(address newToken);


    /// @notice Error emitted when invalid recepient address is passed
    error InvalidRecepientAddressPassed();
    /// @notice Error emitted when invalid signature is passed
    error InvalidSignaturePassed();
    /// @notice Error emitted when invalid data is passed (merkle proof check failed)
    error InvalidDataPassed();
    /// @notice Error emitted when allocation is not found for a user (allocation is 0)
    error AllocationNotFound(address user);
    /// @notice Error emitted when user id is already in use (user id is in bytes from UserSchedule.user)
    error UserIdAlreadyInUse(bytes32 primaryWalletBytes);
    /// @notice Error emitted when transfer of tokens failed
    error TransferFailed();
    /// @notice Error emitted when unauthorized user tries to perform an action
    error Unauthorized();
    /// @notice Error emitted when user already exists
    error UserAlreadyExists();
    /// @notice Error emitted when token address is already set
    error TokenAddressAlreadySet();
    /// @notice Error emitted when invalid signer address is passed (address is 0)
    error InvalidSignerPassed();
    /// @notice Error emitted when invalid token address is passed (address is 0)
    error InvalidTokenPassed();
    
    /// @notice Initialize the contract with the and signer address and merkle root
    constructor(address signerAddress_, bytes32 root_) {
        if (signerAddress_ == address(0)) {
            revert InvalidSignerPassed();
        }
        signerAddress = signerAddress_;
        root = root_;
    }

    /**
     * @notice Function to convert bytes32 to address
     * @param b bytes32 to convert to address
     * @return address
     */
    function bytes32ToAddress(bytes32 b) public pure returns (address) {
        return address(uint160(uint256(b)));
    }

    /**
     * @param userSchedule UserSchedule struct containing user's vesting schedule and their wallet address in bytes
     * @param proof Merkle proof to verify the user's vesting schedule
     * @param recepientAddress Address of the recepient wallet (by default wallet that has vesting schedule associated with it)
     * @param signature Signature to verify the recepient wallet (if it's different from the wallet that has vesting schedule associated with it)
     */
    function activateVesting(UserSchedule calldata userSchedule, bytes32[] calldata proof, address recepientAddress, bytes calldata signature) external nonReentrant {
        bool isValidData = _validateMerkleProof(userSchedule, proof);
        if (!isValidData) {
            revert InvalidDataPassed();
        }
        address actualRecepientAddress = _findRecepientWallet(userSchedule, recepientAddress, signature);
        _seedUser(userSchedule, actualRecepientAddress);
    }

    /**
     * @notice Function to release tokens for a specific user
     * @param to Address of the user to release tokens to
     */
    function releaseTokens(address to) external nonReentrant {
        Schedule storage schedule = schedules[to];
        if (schedule.allocation == 0) {
            revert AllocationNotFound(to);
        }
        
        uint256 amtToClaim = _claimableAmount(schedule);
      
        schedule.claimed += amtToClaim;
        bool success = token.transfer(to, amtToClaim);
        if (!success) {
            revert TransferFailed();
        }

        emit TokensReleased(to, amtToClaim);
    }

    /**
     * @notice Function for users to update their recepient wallet
     * @param userAddressInBytes User id in bytes
     * @param newRecepientWallet New recepient wallet address (should be not 0 and not already in use)
     */
    function updateRecepientWallet(bytes32 userAddressInBytes, address newRecepientWallet) external {
        _updateRecepientWallet(userAddressInBytes, msg.sender, newRecepientWallet);
    }

    /**
     * @notice Function for admin to update the recepient wallet
     * @param userAddressInBytes User id in bytes
     * @param currentRecepientWallet Current recepient wallet address
     * @param newRecepientWallet New recepient wallet address (should be not 0 and not already in use)
     */
    function adminUpdateRecepientWallet(bytes32 userAddressInBytes, address currentRecepientWallet, address newRecepientWallet) external onlyOwner {
        _updateRecepientWallet(userAddressInBytes, currentRecepientWallet, newRecepientWallet);
    }

    /**
     * @notice Function to update the signer address
     * @param signerAddress_ New signer address
     */
    function setSignerAddress(address signerAddress_) external onlyOwner {
        if (signerAddress_ == address(0)) {
            revert InvalidSignerPassed();
        }
        signerAddress = signerAddress_;
        emit SignerAddressSet(signerAddress_);
    }

    /**
     * @notice Function to update the token address
     * @param newToken New token address (should be not 0)
     */
    function updateTokenAddress(IERC20 newToken) external onlyOwner {
        if (address(token) != address(0)) {
            revert TokenAddressAlreadySet();
        }
        if (address(newToken) == address(0)) {
            revert InvalidTokenPassed();
        }
        token = newToken;
        emit TokenAddressUpdated(address(newToken));
    }

    /**
     * @notice Function to calculate claimable amount for a specific user
     * @param user Address of the user
     * @return uint256 accumulated claimable amount
     */
    function claimableAmount(address user) external view returns (uint256) {
        return _claimableAmount(schedules[user]);
    }

    /**
     * @notice Function to calculate claimable amount for a specific user by their id in bytes
     * @param userAddressInBytes User id in bytes
     * @return uint256 accumulated claimable amount
     */
    function claimableAmountById(bytes32 userAddressInBytes) external view returns (uint256) {
        address user = primaryWalletBytesToAddress[userAddressInBytes];
        if (user == address(0)) {
            return 0;
        }

        return _claimableAmount(schedules[user]);
    }

    /**
     * @notice Internal function to initialize a user's vesting schedule
     * @param userSchedule UserSchedule struct containing user's vesting schedule and their wallet address in bytes
     * @param userAddress Address of the user
     */
    function _seedUser(UserSchedule calldata userSchedule, address userAddress) internal {        
        if (schedules[userAddress].allocation != 0) {
            revert UserAlreadyExists();
        }
        
        if (primaryWalletBytesToAddress[userSchedule.user] != address(0)) {
            revert UserIdAlreadyInUse(userSchedule.user);
        }

        primaryWalletBytesToAddress[userSchedule.user] = userAddress;
        schedules[userAddress] = userSchedule.schedule;

        emit ScheduleSet(userAddress, userSchedule.user);
    }

    /**
     * @notice Internal function to update the recepient wallet
     * @param userAddressInBytes User id in bytes
     * @param currentRecepientWallet Current recepient wallet address
     * @param newRecepientWallet New recepient wallet address (should be not 0 and not already in use)
     */
    function _updateRecepientWallet(bytes32 userAddressInBytes, address currentRecepientWallet, address newRecepientWallet) internal {
        if (primaryWalletBytesToAddress[userAddressInBytes] != currentRecepientWallet) {
            revert Unauthorized();
        }
        if (newRecepientWallet == address(0)) {
            revert InvalidRecepientAddressPassed();
        }
        if (schedules[newRecepientWallet].allocation != 0) {
            revert UserAlreadyExists();
        }
        primaryWalletBytesToAddress[userAddressInBytes] = newRecepientWallet;
        schedules[newRecepientWallet] = schedules[currentRecepientWallet];
        delete schedules[currentRecepientWallet];
        emit RecepientAddressUpdated(userAddressInBytes, currentRecepientWallet, newRecepientWallet);
    }

    /**
     * @notice Internal view function to calculate claimable amount for a specific user
     * @param schedule Schedule struct containing user's vesting schedule
     * @return uint256 accumulated claimable amount
     */
    function _claimableAmount(Schedule storage schedule) internal view returns (uint256) {
        return _vestedAmount(schedule) - schedule.claimed;
    }
    
    /**
     * @notice Internal view function to calculate vested amount for a specific user
     * @param schedule Schedule struct containing user's vesting schedule
     * @return uint256 vested amount
     */
    function _vestedAmount(Schedule storage schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTimestamp) {
            return 0;
        }
        if (block.timestamp > schedule.endTimestamp) {
            return schedule.allocation;
        }

        uint256 initialAmt = schedule.allocation * schedule.initUnlockPercentage / 100;
        uint256 vestingAmt = schedule.allocation - initialAmt;    
        
        uint256 elapsedTime = block.timestamp - schedule.startTimestamp;
        uint256 unlockPeriod =  schedule.endTimestamp - schedule.startTimestamp;
        
        return initialAmt + (vestingAmt * elapsedTime) / unlockPeriod;
    }

    /**
     * @notice Internal view function to find the recepient wallet
     * @dev If the sender is the user OR recepient wallet is not passed, then the recepient wallet is the sender's wallet.
     * If the recepient wallet is passed and != sender (SOL users or ETH users who desire to use another address to receive
     * tokens to), then the signature is verified to check if the recepient wallet is valid.
     * @dev isValidEthereumAddress guarantees that user is an Ethereum address and not a Solana address.This ensures that if
     * senders last 20 bytes overlap with the last 20 bytes of Solana address, the transaction will revert and now allow the sender
     * to claim tokens on behalf of the Solana address.
     * @param userSchedule UserSchedule struct containing user's vesting schedule and their wallet address in bytes
     * @param recepientWallet Address of the recepient wallet
     * @param signature Signature to verify the recepient wallet (if it's different from the wallet that has vesting schedule associated with it)
     * @return address of the recepient wallet
     */
    function _findRecepientWallet(UserSchedule calldata userSchedule, address recepientWallet, bytes calldata signature) internal view returns (address) {
        if (msg.sender == bytes32ToAddress(userSchedule.user) && recepientWallet == address(0) && isValidEthereumAddress(userSchedule.user)) {
            return msg.sender;
        }

        if (recepientWallet == bytes32ToAddress(userSchedule.user) && isValidEthereumAddress(userSchedule.user)) {
            return recepientWallet;
        }

        if (recepientWallet == address(0)) {
            revert InvalidRecepientAddressPassed();
        }

        if (_validateSignature(userSchedule.user, recepientWallet, signature)) {
            return recepientWallet;
        }

        revert InvalidSignaturePassed();
    }

    /**
     * @notice Internal view function to validate signature
     * @param user User id in bytes
     * @param recepientWallet Address of the recepient wallet
     * @param signature Signature to verify the recepient wallet
     * @return bool is signature valid
     */
    function _validateSignature(bytes32 user, address recepientWallet, bytes calldata signature) internal view returns (bool) {
      bytes32 dataHash = keccak256(abi.encode(user, recepientWallet));
      bytes32 message = ECDSA.toEthSignedMessageHash(dataHash);

      address receivedAddress = ECDSA.recover(message, signature);
      return (receivedAddress != address(0) && receivedAddress == signerAddress);
    }

    /**
     * @notice Internal view function to validate merkle proof
     * @param userSchedule UserSchedule struct containing user's vesting schedule and their wallet address in bytes
     * @param proof Merkle proof to verify the user's vesting schedule
     * @return bool is merkle proof valid
     */
    function _validateMerkleProof(UserSchedule calldata userSchedule, bytes32[] calldata proof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encode(userSchedule.user, userSchedule.schedule.allocation, userSchedule.schedule.startTimestamp, userSchedule.schedule.endTimestamp, userSchedule.schedule.initUnlockPercentage));
        return MerkleProof.verify(proof, root, leaf);
    }

    /**
     * @notice Internal view function to check if the user is an Ethereum address
     * @param solanaAddress User id in bytes
     * @return bool is Ethereum address
     */
    function isValidEthereumAddress(bytes32 solanaAddress) internal pure returns (bool) {
       return bytes12(solanaAddress) == bytes12(0);
    }
}