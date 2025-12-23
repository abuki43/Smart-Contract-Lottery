// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title A simple Raffle contract
 * @author Abubeker Abe
 * @notice THis contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 playerLength, uint256 raffleState);

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable I_ENTERANCEFEE;
    uint256 private immutable I_INTERVAL;
    bytes32 private immutable I_KEYHASH;
    uint256 private immutable I_SUBSCRIPTIONID;
    uint32 private immutable I_CALLBACKGASLIMIT;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable s_recentWinner;
    RaffleState private s_raffleState;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 enteranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_ENTERANCEFEE = enteranceFee;
        I_INTERVAL = interval;
        I_KEYHASH = gasLane;
        I_SUBSCRIPTIONID = subscriptionId;
        I_CALLBACKGASLIMIT = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= I_ENTERANCEFEE,"Not enough ETH sent!");
        if (msg.value < I_ENTERANCEFEE) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] calldata randomWords
    )
        internal
        virtual
        override
    {
        //CEI pattern
        //checks
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        // effects(internal state ....)
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);

        // interactions(external .....)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /*performData*/
        )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) > I_INTERVAL;
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayer = s_players.length > 0;

        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayer;
    }

    function performUpkeep(
        bytes calldata /*performData*/
    )
        external
        override
    {
        (bool upKeepNeeded,) = checkUpkeep(" ");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: I_KEYHASH,
                subId: I_SUBSCRIPTIONID,
                requestConfirmations: REQUEST_CONFIRMATION,
                callbackGasLimit: I_CALLBACKGASLIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        emit RequestedRaffleWinner(requestId);
    }

    // Getter function

    function getEntranceFee() external view returns (uint256) {
        return I_ENTERANCEFEE;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address) {
        return s_recentWinner;
    }
}
