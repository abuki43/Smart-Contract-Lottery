// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DepoloyRaffle} from "../../script/DepolyRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";


contract RaffleTest is Test {

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 enteranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;


    function setUp() external {
        DepoloyRaffle deployer = new DepoloyRaffle();
        (raffle,helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        enteranceFee = config.enteranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(PLAYER,STARTING_PLAYER_BALANCE);
    }

    function testRaffleIntializesOpenState() public view{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertWhenYouDontPayEnough() public {
        //Arrange
        //Act
        //Asset

        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value:0}();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();

        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true,false,false,false,address(raffle));

        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: enteranceFee}();

    }

    function testDontAllowPlayersToEnterRaffleWhileRffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value:enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");


        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value:enteranceFee}();
    }
}
