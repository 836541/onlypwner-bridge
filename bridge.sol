pragma solidity ^0.8.20;

import {IBridge} from "./interfaces/IBridge.sol";

// Objetivo do CTF
// Mudar stateRoot para 0xdeadbeef 

//    DEPLOY: 1- Manda 1 ether pro User.    2- registerValidator de 100 Ether pro adress(0) numa tag aleatoria 
//        payable(user).transfer(1 ether);
//        bridge.registerValidator{value: 100 ether}(address(0), "Some Tag");

//        console.log("address:Bridge", address(bridge));



contract Bridge is IBridge {
    address public override owner;
    address[] public override admins;
    mapping(address => ValidatorInfo) private _validators;
    mapping(bytes32 => mapping(address => bool)) public override votedOn;
    mapping(bytes32 => uint256) public override votesFor;
    bytes32 public override stateRoot;

    uint256 constant PREFIX_LENGTH = 0x4 + 0x20 + 0x20;

    // Modifier onlyValidator()
    // Requisito pra ser validator: estar na array com um valor de deposit 
    modifier onlyValidator() {
        require(
            _validators[msg.sender].deposit > 0,
            "Bridge: caller is not a validator"
        );
        _;
    }

    // onlyOwner() padrao 
    modifier onlyOwner() {
        require(msg.sender == owner, "Bridge: caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Votar pra um novo Root
    // Apenas Validators podem votar
    // Inputa 1- Novo Root   2- Contra/A Favor 
    function voteForNewRoot(
        bytes calldata vote
    ) external override onlyValidator {
        (bytes32 newRoot, bool isFor, ) = decodeCompressedVote(vote);
        handleNewVote(newRoot, isFor);

        if (isFor) {
            tryActivateStateRoot(newRoot);
        }
    }

    // Registra um novo Validator (votador de roots)
    // 1- Deve pagar pelo menos 1 Ether
    // 2 - Deve nunca ter depositado antes no protocolo
    // 3 - Adiciona pro mapping de validator na struct -> deposit value, referrer e tag 
    function registerValidator(
        address referrer,
        bytes32 tag
    ) external payable override {
        require(msg.value >= 1 ether, "Bridge: insufficient deposit");
        require(
            _validators[msg.sender].deposit == 0,
            "Bridge: already registered"
        );

        _validators[msg.sender] = ValidatorInfo({
            deposit: msg.value,
            referrer: referrer,
            tag: tag
        });

        emit ValidatorRegistered(msg.sender, tag);
    }

    // Owner pode adicionar novo admin 
    function addAdmin(address admin) external override onlyOwner {
        admins.push(admin);
    }

    // Function para ver os Validators 
    function validators(
        address validator
    ) external view override returns (ValidatorInfo memory) {
        return _validators[validator];
    }

    function decodeCompressedVote(
        bytes memory vote
    ) private pure returns (bytes32 newRoot, bool isFor, uint48 ts) {
        require(
            vote.length <= PREFIX_LENGTH + 0x28,
            "Bridge: invalid vote length"
        );

        assembly {
            calldatacopy(0x0, PREFIX_LENGTH, calldatasize())
            newRoot := mload(0x0)
            isFor := mload(0x20)
            ts := shr(mload(0x22), 0x20)
        }
    }

    // Novo Voto 
    // 1- mapping de Root Novo -> Msg.Sender = True 
    // 2- Se votar contra, nada muda
    // 3- Votos para o Novo Root eh de acordo com seu valor depositado na vida toda
    function handleNewVote(bytes32 newRoot, bool isFor) private {
        require(
            !votedOn[newRoot][msg.sender],
            "Bridge: validator already voted"
        );
        votedOn[newRoot][msg.sender] = true;

        if (!isFor) {
            return;
        }

        votesFor[newRoot] += _validators[msg.sender].deposit;
    }

    // Tenta ativar um novo State Root
    // 1- Verifica se um admin ta tentando ativar
    // 2- Se admin ou Se Votos pra esse root >= 100 ether ----> muda root, e reseta os votos
    function tryActivateStateRoot(bytes32 root) private {
        ValidatorInfo memory info = _validators[msg.sender];
        address[] memory currentAdmins = getAdmins();

        bool isAdmin = false;
        for (uint256 i = 0; i < currentAdmins.length; i++) {
            if (currentAdmins[i] == msg.sender) {
                isAdmin = true;
                break;
            }
        }

        if (isAdmin || votesFor[root] >= 100 ether) {
            votesFor[root] = 0;
            stateRoot = root;
            emit NewStateRoot(root, info.tag);
        }
    }

    // View dos admins atuais
    function getAdmins() private view returns (address[] memory result) {
        if (admins.length > 0) {
            result = new address[](admins.length);
            for (uint256 i = 0; i < admins.length; i++) {
                result[i] = admins[i];
            }
        }
    }
}

// 