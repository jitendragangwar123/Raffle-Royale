// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A sample Raffle Contract
 * @author Jitendra Kumar
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2 and Chainlink Automation
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* Errors */
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
    error Raffle__TransferFailed();
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();

    /* Type declarations */
    /**
     * @dev Enum to represent the state of the raffle.
     * OPEN: The raffle is open for entries.
     * CALCULATING: The raffle is calculating the winner.
     */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State variables */
    // Chainlink VRF Variables
    /**
     * @notice Subscription ID for Chainlink VRF.
     */
    uint256 private immutable i_subscriptionId;

    /**
     * @notice Gas lane key hash for Chainlink VRF.
     */
    bytes32 private immutable i_gasLane;

    /**
     * @notice Callback gas limit for Chainlink VRF requests.
     */
    uint32 private immutable i_callbackGasLimit;

    /**
     * @notice Number of confirmations required for Chainlink VRF requests.
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    /**
     * @notice Number of random words requested from Chainlink VRF.
     */
    uint32 private constant NUM_WORDS = 1;

    // Lottery Variables
    /**
     * @notice Time interval between raffle runs.
     */
    uint256 private immutable i_interval;

    /**
     * @notice Entrance fee required to join the raffle.
     */
    uint256 private immutable i_entranceFee;

    /**
     * @notice Timestamp of the last raffle run.
     */
    uint256 private s_lastTimeStamp;

    /**
     * @notice Address of the most recent winner.
     */
    address private s_recentWinner;

    /**
     * @notice List of players currently in the raffle.
     */
    address payable[] private s_players;

    /**
     * @notice Current state of the raffle.
     */
    RaffleState private s_raffleState;

    /* Events */
    /**
     * @notice Emitted when a random winner is requested.
     * @param requestId The ID of the VRF request.
     */
    event RequestedRaffleWinner(uint256 indexed requestId);

    /**
     * @notice Emitted when a player enters the raffle.
     * @param player The address of the player who entered.
     */
    event RaffleEnter(address indexed player);

    /**
     * @notice Emitted when a winner is picked.
     * @param player The address of the winning player.
     */
    event WinnerPicked(address indexed player);

    /* Functions */
    /**
     * @notice Constructor for the Raffle contract.
     * @param subscriptionId Chainlink VRF subscription ID.
     * @param gasLane Gas lane key hash for Chainlink VRF.
     * @param interval Time interval between raffle runs.
     * @param entranceFee Entrance fee required to join the raffle.
     * @param callbackGasLimit Callback gas limit for Chainlink VRF requests.
     * @param vrfCoordinatorV2 Address of the Chainlink VRF Coordinator.
     */
    constructor(
        uint256 subscriptionId,
        bytes32 gasLane, 
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
    }

    /**
     * @notice Allows a user to enter the raffle by paying the entrance fee.
     * @dev Reverts if the raffle is not open or if the sent ETH is less than the entrance fee.
     */
    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /**
     * @notice Checks if the upkeep is needed for the raffle.
     * @dev Called by Chainlink Keepers to determine if performUpkeep should be executed.
     * @return upkeepNeeded Boolean indicating whether upkeep is needed.
     * @return performData Placeholder return value (not used).
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // Placeholder return value
    }

    /**
     * @notice Performs the upkeep for the raffle, triggering the winner selection process.
     * @dev Called by Chainlink Keepers when checkUpkeep returns true.
     */
    function performUpkeep(bytes calldata /* performData */ ) external override {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @notice Fulfills the randomness request and determines the raffle winner.
     * @dev Called by Chainlink VRF Coordinator with the random words.
     * @param randomWords Array of random words provided by Chainlink VRF.
     */
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * @notice Returns the current state of the raffle.
     */
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    /**
     * @notice Returns the number of random words requested from Chainlink VRF.
     */
    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    /**
     * @notice Returns the number of confirmations required for Chainlink VRF requests.
     */
    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    /**
     * @notice Returns the address of the most recent winner.
     */
    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    /**
     * @notice Returns the address of a player at a specific index.
     * @param index The index of the player in the players array.
     */
    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    /**
     * @notice Returns the timestamp of the last raffle run.
     */
    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    /**
     * @notice Returns the time interval between raffle runs.
     */
    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    /**
     * @notice Returns the entrance fee required to join the raffle.
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    /**
     * @notice Returns the number of players currently in the raffle.
     */
    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}