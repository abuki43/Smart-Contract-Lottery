// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";

contract IntegrationTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public player = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;


    function setup() external {
        DeployRaffle deployerRaffle = new DeployRaffle();
        (raffle,helperConfig) = deployerRaffle.deployContract();
        
        vm.deal(player,STARTING_PLAYER_BALANCE);
    }

}