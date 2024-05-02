//enter the lottery
//pick a random winner (verifiable)
// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.7;
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "hardhat/console.sol";

error lottery__NotenoughETHentered();
error lottery__TranseferedFAiled();
error lottery__RaffleState_NOTOPEN();
error lottery__UpkeepNotNeeded(
    uint256 currentBalance,
    uint256 playerslength,
    uint256 rafflestate
);

/**

@title lottery contract
@author vishnu
@notice this contract is for creationg a dapp for lottery
@dev this implements chainlink VRFV2 AND CHAINLINKKEEPERS
*/
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /* TYPE DECLERATIONS*/
    enum RaffleState {
        OPEN,
        CALCULATING
    } //it means uint 256 = 0 open,1=open

    /*state variables*/
    uint256 immutable i_entrancefees;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subid;
    uint32 private immutable i_callbackGaslimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    //lotteryvariables

    address private s_recentWinner;
    RaffleState private s_rafflestate; // can be pending true flase calculating
    //this is little bit tricky so we use ENUM
    uint256 private s_lastTimestamp;
    uint256 private immutable i_interval;

    /* EVENTS*/
    event raffleentre(address indexed player);
    event RequestedRaffle(uint256 indexed reqid);
    event WinnerPicked(address indexed winner);

    /*functions*/

    constructor(
        address vrfCoordinatorV2,
        uint64 subid,
        bytes32 gasLane,
        uint256 interval,
        uint256 entarncefees,
        uint32 gaslimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entrancefees = entarncefees;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2); //to get the entrance value
        i_gaslane = gasLane;
        i_subid = subid;
        i_callbackGaslimit = gaslimit;
        s_rafflestate = RaffleState.OPEN; //can enter in the lottery
        s_lastTimestamp = block.timestamp;
        i_interval = interval;
    }

    function entreRaffle() public payable {
        if (msg.value < i_entrancefees) {
            revert lottery__NotenoughETHentered();
        }
        if (s_rafflestate != RaffleState.OPEN) {
            revert lottery__RaffleState_NOTOPEN();
        }
        s_players.push(payable(msg.sender));
        emit raffleentre(msg.sender);
    }

    /**
     * @dev this is the function that chain link keeper nodes call
     * they look for the unkeeped data to return the true
     * following should be true to be true
     * 1.our time interval should have passed
     * 2.the lottery should have atleast 1 player,and some eth
     * 3.our subscription funded with link
     * 4.lott should be in open state
     */
    function checkUpkeep(
        bytes memory /*checkdata*/
    )
        public
        view
        override
        returns (bool upkeepneeded, bytes memory /*performdata*/)
    {
        bool isOpen = (RaffleState.OPEN == s_rafflestate);
        //to check current time of block we use block.timestamp-last blocktimestamp
        bool timePassed = ((block.timestamp - s_lastTimestamp) > i_interval);
        bool hasplayers = (s_players.length > 0);
        bool hasbalance = address(this).balance > 0;
        upkeepneeded = (isOpen && timePassed && hasplayers && hasbalance);
        return (upkeepneeded, "0x0");

        //from chainlink
    }

    //EVENTS emit whenever we update our array
    //this all will be done by vrf chain link
    // request the random winner
    //once we get it do something
    //2 transaction process
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepneeded, ) = checkUpkeep("");
        if (!upkeepneeded) {
            revert lottery__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_rafflestate)
            );
        }

        s_rafflestate = RaffleState.CALCULATING;

        uint256 reqid = i_vrfCoordinator.requestRandomWords(
            i_gaslane, //gaslane
            i_subid,
            REQUEST_CONFIRMATIONS,
            i_callbackGaslimit,
            NUM_WORDS
        );
        emit RequestedRaffle((reqid));
    }

    function fulfillRandomWords(
        //pick a random winner from ARRAY

        uint256 /*requestID,*/,
        uint256[] memory randomWords
    ) internal override {
        //suppose
        //s_players size is 10
        //random number is 200
        //so we use modulo function(%)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentwinner = s_players[indexOfWinner];
        s_recentWinner = recentwinner;
        s_rafflestate = RaffleState.OPEN;
        s_players = new address payable[](0); //resetting the array;
        s_lastTimestamp = block.timestamp;
        (bool success, ) = recentwinner.call{value: address(this).balance}(""); //returning the balance
        if (!success) {
            revert lottery__TranseferedFAiled();
        }
        emit WinnerPicked(recentwinner);
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entrancefees;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getrafflestate() public view returns (RaffleState) {
        return s_rafflestate;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberofPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLastestTS() public view returns (uint256) {
        return s_lastTimestamp;
    }

    function getRequestedconf() public pure returns (uint256) {
        //pure is used for constants
        return REQUEST_CONFIRMATIONS;
    }
}
