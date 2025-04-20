// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Verifier.sol";
import "./VRFConsumerBase.sol";


contract PetitionPoll is VRFConsumerBase {
    Verifier public verifier;

    bytes32 internal keyHash;
    uint256 internal fee;


    //constructor(
       // address _verifier,
       // address _vrfCoordinator,
        //address _linkToken,
        //bytes32 _keyHash,
        //uint256 _fee
    //) VRFConsumerBase(_vrfCoordinator, _linkToken) {
      //  verifier = Verifier(_verifier);
        //keyHash = _keyHash;
        //fee = _fee;
    //}

    constructor(address _verifier) VRFConsumerBase(address(0), address(0)) {
    verifier = Verifier(_verifier);
    keyHash = 0;
    fee = 0;
}


    // Petition Struct
    struct Petition {
        uint256 id;
        address creator;
        string title;
        string description;
        bytes32 merkleRoot;
        bool validated;
        uint256 signatureCount;
        mapping(bytes32 => bool) nullified;
    }

    // Poll Struct
    struct Poll {
        uint256 id;
        address creator;
        string question;
        string[] options;
        bytes32 merkleRoot;
        bool finalized;
        uint256 deadline;
        mapping(uint256 => uint256) votes;
        mapping(bytes32 => bool) nullified;
        uint256 randomResult;
    }

    uint256 public petitionCount;
    uint256 public pollCount;

    mapping(uint256 => Petition) public petitions;
    mapping(uint256 => Poll) public polls;

    event PetitionCreated(uint256 indexed id);
    event PetitionValidated(uint256 indexed id);
    event PetitionSigned(uint256 indexed id);
    event PollCreated(uint256 indexed id, uint256 deadline);
    event VoteCast(uint256 indexed pollId);
    event PollFinalized(uint256 indexed pollId, uint256 winnerIndex);

    // Petition Functions
    function createPetition(
        string calldata title,
        string calldata description,
        bytes32 merkleRoot
    ) external {
        petitionCount++;
        Petition storage p = petitions[petitionCount];
        p.id = petitionCount;
        p.creator = msg.sender;
        p.title = title;
        p.description = description;
        p.merkleRoot = merkleRoot;
        emit PetitionCreated(p.id);
    }

    function validatePetition(
        uint256 petitionId,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input
    ) external {
        Petition storage p = petitions[petitionId];
        require(msg.sender == p.creator, "Only creator");
        require(!p.validated, "Already validated");
        bool ok = verifier.verifyProof(a, b, c, input);
        require(ok, "Invalid proof");
        p.validated = true;
        emit PetitionValidated(petitionId);
    }

    function signPetition(
        uint256 petitionId,
        bytes32 nullifierHash,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input
    ) external {
        Petition storage p = petitions[petitionId];
        require(p.validated, "Not validated");
        require(!p.nullified[nullifierHash], "Already signed");
        bool ok = verifier.verifyProof(a, b, c, input);
        require(ok && input[0] == uint256(p.merkleRoot), "Invalid proof/root");
        p.nullified[nullifierHash] = true;
        p.signatureCount++;
        emit PetitionSigned(petitionId);
    }

    // Poll Functions
    function createPoll(
        string calldata question,
        string[] calldata options,
        bytes32 merkleRoot,
        uint256 durationSeconds
    ) external {
        require(options.length >= 2, "At least 2 options");
        pollCount++;
        Poll storage pl = polls[pollCount];
        pl.id = pollCount;
        pl.creator = msg.sender;
        pl.question = question;
        pl.merkleRoot = merkleRoot;
        pl.deadline = block.timestamp + durationSeconds;
        for (uint i = 0; i < options.length; i++) {
            pl.options.push(options[i]);
        }
        emit PollCreated(pl.id, pl.deadline);
    }

    function vote(
        uint256 pollId,
        uint256 optionIndex,
        bytes32 nullifierHash,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input
    ) external {
        Poll storage pl = polls[pollId];
        require(block.timestamp <= pl.deadline, "Voting closed");
        require(!pl.nullified[nullifierHash], "Already voted");
        require(optionIndex < pl.options.length, "Invalid option");
        bool ok = verifier.verifyProof(a, b, c, input);
        require(ok && input[0] == uint256(pl.merkleRoot), "Invalid proof/root");
        pl.nullified[nullifierHash] = true;
        pl.votes[optionIndex]++;
        emit VoteCast(pollId);
    }

    function finalizePoll(uint256 pollId) external returns (bytes32 requestId) {
        Poll storage pl = polls[pollId];
        require(block.timestamp > pl.deadline, "Poll still active");
        require(!pl.finalized, "Already finalized");

        uint256 maxVotes;
        uint256 winner;
        for (uint i = 0; i < pl.options.length; i++) {
            if (pl.votes[i] > maxVotes) {
                maxVotes = pl.votes[i];
                winner = i;
            }
        }

        uint256 tieCount;
        for (uint i = 0; i < pl.options.length; i++) {
            if (pl.votes[i] == maxVotes) tieCount++;
        }

        if (tieCount > 1) {
            require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
            requestId = requestRandomness(keyHash, fee);
        } else {
            pl.finalized = true;
            pl.randomResult = winner;
            emit PollFinalized(pollId, winner);
        }
    }

    function fulfillRandomness(bytes32, uint256 randomness) internal override {
        Poll storage pl = polls[pollCount];
        uint256 winner = randomness % pl.options.length;
        pl.finalized = true;
        pl.randomResult = winner;
        emit PollFinalized(pl.id, winner);
    }

    function getPollResults(uint256 pollId) external view returns (
        string[] memory options,
        uint256[] memory counts,
        bool finalized,
        uint256 winnerIndex
    ) {
        Poll storage pl = polls[pollId];
        uint256 len = pl.options.length;
        uint256[] memory _counts = new uint256[](len);
        for (uint i = 0; i < len; i++) {
            _counts[i] = pl.votes[i];
        }
        return (pl.options, _counts, pl.finalized, pl.randomResult);
    }
}
