//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {

    // ----------- VARIABLES ----------- //

    address immutable i_owner; //the admin address, assigned at begining of contract with constructor();

    uint winningProposalId; // the winning proposal's index;
    uint nbrVoters; //the amount of address who actually voted

    mapping (address => bool) whitelist; //the whitelist of electors - proposers added by the admin;
    mapping (address => Voter) user_data; //

    struct Voter { //The variables a voter has 
        bool isRegistered; //is he in the whitelist ?
        bool hasVoted;     //has he voted yet ?
        uint votedProposalId; //the index of the proposal he voted for
    }

    struct Proposal { // proposals whitelisted persons can make
        string description;
        uint voteCount; // Number of addresses who voted for this proposal
    }

    Proposal[] proposals; // an array of struct Proposal to keep in memory every proposals

    enum WorkflowStatus {
        RegisteringVoters, // 0
        ProposalsRegistrationStarted, // 1
        ProposalsRegistrationEnded, // 2
        VotingSessionStarted, // 3
        VotingSessionEnded, // 4
        VotesTallied  // 5
    }

    WorkflowStatus public state  = WorkflowStatus.RegisteringVoters; // enum initiated with index 0 state.

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    event WinnerIs (string proposal, uint votesCount, uint votesPercentage); //custom event to see more details onthe winner (+ votes percentage).

    // ----------- FUNCTIONS ----------- //

    constructor() {
        i_owner = msg.sender; // contract deployer is the owner (admin)
        whitelist[i_owner] = true; //the admin can also vote, just like the others whitelisted persons. 
    }

    modifier whitelisted () { //to check if the contract user (msg.sender) is whitelisted.
        require (whitelist[msg.sender], "User must be Whitelisted.");
        _;
    }

    function a_addToWhitelist (address _address) public onlyOwner { //only the owner can add the addresses he selects to the whitelist
        require (whitelist[_address] == false, "User is already whitelisted.");
        whitelist[_address] = true; // adds someone's address in the whitelist and 'enables' it with a bool true;
        emit VoterRegistered (_address); //triggers event that we registred a new voter.
        user_data[_address].isRegistered = true; //user is indeed whitelisted.
    }

    function b_startProposals () public onlyOwner { //owner triggers proposals session event
        require (state == WorkflowStatus.RegisteringVoters, "You cannot start proposals session now."); //can be triggered only after the voters registration on whitelist
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
        state = WorkflowStatus.ProposalsRegistrationStarted;
    }

    function c_propose (string memory _proposal) public whitelisted { //a whitelisted user makes a vote proposal (string)
        require (state == WorkflowStatus.ProposalsRegistrationStarted, "You cannot make proposal now."); //only if the proposal session is ongoing
        Proposal memory newProposal = Proposal(_proposal, 0);
        proposals.push(newProposal);
        emit ProposalRegistered(proposals.length - 1); //proposals.length - 1 : the current proposal's index
    }

    function d_endProposals () public onlyOwner { //the owner ends proposals session
        require (state == WorkflowStatus.ProposalsRegistrationStarted, "You cannot end proposals now."); //only if proposals session is ongoing
        state = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    function seeProposals () public view whitelisted returns (Proposal[] memory) {
        require (state != WorkflowStatus.RegisteringVoters, "You cannot see proposals now.");
        return (proposals); //returns an arry of the proposals + vote count. only after the whitelist registration.
    }

    function seeSomeoneVote (address _address) public view whitelisted returns (string memory) { //to see for what user 0x voted.
        require (whitelist[_address], "Searched user must be whitelisted so you can see his vote");
        require (user_data[_address].hasVoted, "Searched user has not voted yet.");
        uint idx = user_data[_address].votedProposalId; // retrieve index of proposal id the _address voted for
        return (proposals[idx].description); // displays the proposal itself thanks to the idx
    }

    function e_startVotingSession () public onlyOwner { //whitelisted persons can now start to vote.
        require (state == WorkflowStatus.ProposalsRegistrationEnded, "You cannot start voting session now.");
        state = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    function f_vote (uint proposal_index) public whitelisted { //
        require (state == WorkflowStatus.VotingSessionStarted, "You cannot vote yet.");
        require (user_data[msg.sender].hasVoted == false, "You already voted."); // 1 vote per whitelisted address.
        require (proposal_index < proposals.length, "Your vote index must fit the proposals array size - 1.");
        proposals[proposal_index].voteCount++; //increment the vote for a proposal in the array 
        user_data[msg.sender].votedProposalId = proposal_index; // we know for what the user voted
        user_data[msg.sender].hasVoted = true; // now he cannot vote anymore
        nbrVoters++; //useful for percentage calculation
        emit Voted (msg.sender, proposal_index);
    }
    
    function g_endVotingSession () public onlyOwner { //the end. admin decision.
        require (state == WorkflowStatus.VotingSessionStarted, "The voting session must be ongoing.");
        state = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    function h_countVotes () public onlyOwner {
        require (state == WorkflowStatus.VotingSessionEnded, "The voting session must be have ended to count votes.");
        uint i = 0;
        uint max = proposals[0].voteCount;
        while (i < proposals.length) //a loop to check each vote count per proposal.
        {
            if (proposals[i].voteCount > max) //is current maximum higher than previous registred maximum ?
            {
                max = proposals[i].voteCount;
                winningProposalId = i;
            }
            i++;
        }
        state = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    function getWinner () public view returns (string memory) {
        require (state == WorkflowStatus.VotesTallied, "The votes count must have ended.");
        return (proposals[winningProposalId].description); //returns winning proposition
    }

    function i_getWinnerWithDetails () public { //shows winning proposition + vote count + percentage of votes it received
        require (state == WorkflowStatus.VotesTallied, "The votes count must have ended.");
        emit WinnerIs (proposals[winningProposalId].description, proposals[winningProposalId].voteCount, (proposals[winningProposalId].voteCount * 100) / nbrVoters);
    }
    
}