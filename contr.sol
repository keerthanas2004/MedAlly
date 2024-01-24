// SPDX-License-Identifier: MIT
pragma solidity ^0.5.1;

contract HealthRecordSystem {
    address payable public admin; // Contract administrator
    mapping(address => bool) public isDoctor; // Mapping to track doctors
    mapping(address => PatientData) public patientData; // Mapping to store patient data
    mapping(address => uint256) public pendingRequests; // Mapping to track pending data requests

    event DataRequested(address indexed requester, address indexed patient);
    event DataShared(address indexed patient, address indexed requester, string data, uint256 amount);

    struct PatientData {
        string data;
        address doctor;
        uint256 expirationTime;
        bool isEmergency;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    modifier onlyDoctor() {
        require(isDoctor[msg.sender], "Not authorized");
        _;
    }

    modifier onlyAuthorized(address patient) {
        require(msg.sender == patient || now < patientData[patient].expirationTime, "Not authorized");
        _;
    }

    constructor() public {
        admin = msg.sender;
    }

    // Add a doctor to the system (only admin)
    function addDoctor(address _doctor) external onlyAdmin {
        isDoctor[_doctor] = true;
    }

    // Upload or update patient data (only doctor)
    function uploadOrUpdateData(
        address _patient,
        string calldata _data,
        uint256 _expirationTime,
        bool _isEmergency
    ) external onlyDoctor {
        patientData[_patient].data = _data;
        patientData[_patient].doctor = msg.sender;
        patientData[_patient].expirationTime = now + _expirationTime;
        patientData[_patient].isEmergency = _isEmergency;

        if (_isEmergency) {
            emit EmergencyAlert(_patient, "Emergency data updated");
        }
    }

    // Request patient data (either through doctor or directly)
    function requestData(address _patient) external {
        emit DataRequested(msg.sender, _patient);
    }

    // Approve data request and share data (only patient or DAO community)
    function approveAndShareData(
        address _patient,
        address _requester,
        string calldata _data,
        uint256 _amount
    ) external onlyAuthorized(_patient) {
        require(pendingRequests[_requester] > 0, "No pending request");

        // Distribute payment
        uint256 patientShare = (_amount * 70) / 100; // 70% for the patient
        uint256 middlePartyShare = (_amount * 20) / 100; // 20% for the middle party (DAO community)
        uint256 doctorShare = _amount - patientShare - middlePartyShare; // 10% for the doctor

        // Transfer funds
        pendingRequests[_requester] = 0;
        address(uint160(_requester)).transfer(patientShare);
        address(uint160(patientData[_patient].doctor)).transfer(doctorShare);
        admin.transfer(middlePartyShare);

        // Emit event
        emit DataShared(_patient, _requester, _data, _amount);
    }

    // Reject data request (only patient or DAO community)
    function rejectDataRequest(address _requester) external onlyAuthorized(msg.sender) {
        require(pendingRequests[_requester] > 0, "No pending request");

        // Refund the requester
        uint256 refundAmount = pendingRequests[_requester];
        pendingRequests[_requester] = 0;
        address(uint160(_requester)).transfer(refundAmount);
    }

    // Emergency alert event
    event EmergencyAlert(address indexed patient, string message);
}

