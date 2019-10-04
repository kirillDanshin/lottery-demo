pragma solidity ^0.5.4;

contract Lottery {
    struct Participant {
        bytes32 next;

        address payable addr;
        uint64          tickets;
    }
    mapping(bytes32 => Participant) internal participants;
    bytes32 internal participantHeadElem;
    bytes32 internal participantTailElem;
    uint32  internal lotteryGen;
    bytes32 internal lotteryHash;

    uint256 internal contractBalance;

    address internal owner;

    event TicketsBought(address indexed _by, uint _quantity);
    event LotteryFinished(address indexed _winner, uint _quantity);
    event LotteryReset();

    constructor() public {
        owner = msg.sender;
    }

    function() external payable {
        buyTickets();
    }

    function buyTickets() public payable {
        require(msg.value >= 100 finney, "you can buy tickets starting from 100 finney (0.1 ether)");
        // if tailElement is defined, then assign the next element
        if (participants[participantTailElem].addr != address(0x0)) {
            participants[participantTailElem].next = key(msg.sender);
        }
        Participant memory p = participants[key(msg.sender)];
        if (p.addr == address(0x0)) {
            participants[key(msg.sender)] = Participant(
                bytes32(0x0),
                msg.sender,
                0
            );
            // tail element should change only if msg.sender is not participating
            // in current lotteryGen.
            participantTailElem = key(msg.sender);
        }
        participants[key(msg.sender)].tickets += uint64(msg.value / 100 finney);
        lotteryHash = keccak256(abi.encodePacked(
            lotteryHash,
            msg.sender,
            msg.value,
            lotteryGen,
            rot(participants[key(msg.sender)].tickets),
            participantHeadElem,
            key(msg.sender)
        ));
        // if head element is not defined, define it.
        // we do it here to increase lotteryHash entropy.
        // if we update it before keccak256 call, then we
        // would basically get `key(msg.sender)` twice in the end.
        if (participants[participantHeadElem].addr == address(0x0)) {
            participantHeadElem = key(msg.sender);
        }
        lotteryHash = keccak256(abi.encodePacked(lotteryHash));
        contractBalance += msg.value;
        emit TicketsBought(msg.sender, participants[key(msg.sender)].tickets);
    }

    function nextLottery() internal {
        lotteryGen++;
        contractBalance = 0;
        participantHeadElem = 0x0;
        participantTailElem = 0x0;
        lotteryHash = 0x0;
        emit LotteryReset();
    }

    function key(address _addr) internal view returns(bytes32) {
        return keccak256(abi.encodePacked(lotteryGen, _addr));
    }

    function awardWinnerAndRestart() public {
        require(msg.sender == owner, "method available only for owners");
        awardWinner();
        nextLottery();
    }

    function awardWinner() private returns (uint256) {
        uint256 totalTickets = contractBalance / 100 finney;
        require(totalTickets > 0, "you must sell a few tickets before rewarding");
        uint256 randomN = uint256(keccak256(abi.encodePacked(msg.sender, blockhash(block.number), lotteryHash, participantHeadElem)));

        uint256 winnerTicket = randomN % totalTickets;
        uint256 processedTickets = 0;

        bytes32 currElemKey = participantHeadElem;
        address payable winner = address(0x0);
        while (currElemKey != 0x0) {
            processedTickets += participants[currElemKey].tickets;
            if (processedTickets >= winnerTicket) {
                winner = participants[currElemKey].addr;
                break;
            }
            currElemKey = participants[currElemKey].next;
        }

        // could also either transfer the balance to owner or refund
        // all tickets. depends on business logic.
        require(winner != address(0x0), "winner could not be 0x0");

        winner.transfer(contractBalance);
        emit LotteryFinished(winner, contractBalance);
    }

    function rot(uint256 x) private pure returns (uint256) {
        uint256 z = x ^ (x >> 12);
        z ^= z << 25;
        z ^= z << 27;

        return z * 0x2545F4914F6CDD1D;
    }
}
