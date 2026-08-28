package Hospital_Bed_System {
    import ScalarValues::*;

    // ---- Unit Definitions ----
    unit def deg;
    unit def mm;
    unit def kg;
    unit def kPa;
    unit def N;
    unit def V;
    unit def A;
    unit def s;

    // ---- Value Type Definitions ----
    value def AngleValue :> Real;
    value def HeightValue :> Real;
    value def WeightValue :> Real;
    value def PressureValue :> Real;
    value def ForceValue :> Real;
    value def VoltageValue :> Real;
    value def CurrentValue :> Real;
    value def TimeValue :> Real;
    value def TorqueValue :> Real;

    // ---- Enumeration Definitions ----
    enum def AlertType {
        patientExit;
        pressureUlcerRisk;
        weightCapacityExceeded;
        mechanicalLimitReached;
    }

    enum def AlertSeverity {
        info;
        warning;
        critical;
    }

    enum def CommandType {
        adjustHead;
        adjustFoot;
        adjustHeight;
        emergencyStop;
        queryStatus;
    }

    enum def MotorStatus {
        idle;
        moving;
        fault;
    }

    enum def PowerStatus {
        on;
        off;
        fault;
    }

    enum def BedSectionId {
        head;
        foot;
    }

    // ---- Item Type Definitions ----
    item def PressureReading {
        attribute sensorId : Integer;
        attribute pressure : PressureValue;
        attribute timestamp : TimeValue;
    }

    item def PressureMap {
        attribute readings : PressureReading[16];
        attribute timestamp : TimeValue;
        attribute maxPressure : PressureValue;
    }

    item def WeightReading {
        attribute totalWeight : WeightValue;
        attribute timestamp : TimeValue;
        attribute isStable : Boolean;
    }

    item def BedConfiguration {
        attribute headAngle : AngleValue;
        attribute footAngle : AngleValue;
        attribute height : HeightValue;
    }

    item def AlertMessage {
        attribute alertType : AlertType;
        attribute severity : AlertSeverity;
        attribute description : String;
        attribute timestamp : TimeValue;
    }

    item def CaregiverCommand {
        attribute commandType : CommandType;
        attribute targetHeadAngle : AngleValue;
        attribute targetFootAngle : AngleValue;
        attribute targetHeight : HeightValue;
    }

    item def BedStatus {
        attribute configuration : BedConfiguration;
        attribute patientWeight : WeightValue;
        attribute pressureMap : PressureMap;
        attribute systemState : String;
        attribute activeAlerts : AlertMessage[*];
    }

    item def Electricity {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    // ---- Port Definitions ----
    port def PowerPort {
        out item power : Electricity;
    }

    port def PressureSensorPort {
        out item pressureReading : PressureReading;
    }

    port def LoadCellPort {
        out item forceReading : ForceValue;
    }

    port def MotorControlPort {
        in item command : CaregiverCommand;
        out item status : MotorStatus;
        out item currentPosition : Real;
    }

    port def ActuatorControlPort {
        in item command : CaregiverCommand;
        out item status : MotorStatus;
        out item currentHeight : HeightValue;
    }

    port def CaregiverInterfacePort {
        in item command : CaregiverCommand;
        out item statusReport : BedStatus;
        out item alert : AlertMessage;
    }

    port def SensorDataPort {
        out item pressureMap : PressureMap;
        out item weightReading : WeightReading;
    }

    port def ControllerCommandPort {
        out item headCommand : CaregiverCommand;
        out item footCommand : CaregiverCommand;
        out item heightCommand : CaregiverCommand;
    }

    // ---- Part Definitions: Sensors ----
    part def PressureSensor {
        attribute sensorId : Integer;
        attribute currentPressure : PressureValue;
        attribute samplingRate : Real = 10.0;
        port sensorPort : PressureSensorPort;

        action def sensePressure {
            out reading : PressureReading;
        }

        perform sensePressure;
    }

    part def LoadCell {
        attribute cellId : Integer;
        attribute currentForce : ForceValue;
        attribute calibrationFactor : Real = 1.0;
        port cellPort : LoadCellPort;

        action def measureForce {
            out reading : ForceValue;
        }

        perform measureForce;
    }

    // ---- Part Definitions: Actuators ----
    part def ElectricMotor {
        attribute maxTorque : TorqueValue;
        attribute currentPosition : Real;
        attribute minPosition : Real;
        attribute maxPosition : Real;
        attribute targetPosition : Real;
        attribute commandReceived : Boolean = false;
        attribute positionReached : Boolean = false;
        attribute limitExceeded : Boolean = false;
        attribute resetRequested : Boolean = false;
        port controlPort : MotorControlPort;

        state def MotorStateMachine {
            entry; then idle;

            state idle;
            state moving;
            state fault;

            transition idle to moving when commandReceived;
            transition moving to idle when positionReached;
            transition moving to fault when limitExceeded;
            transition fault to idle when resetRequested;
        }

        perform MotorStateMachine;
    }

    part def LinearActuator {
        attribute minHeight : HeightValue = 300 [mm];
        attribute maxHeight : HeightValue = 800 [mm];
        attribute currentHeight : HeightValue = 500 [mm];
        attribute targetHeight : HeightValue;
        attribute raiseRequested : Boolean = false;
        attribute lowerRequested : Boolean = false;
        attribute heightReached : Boolean = false;
        attribute limitExceeded : Boolean = false;
        attribute resetRequested : Boolean = false;
        port actuatorPort : ActuatorControlPort;

        part motor : ElectricMotor {
            redefines minPosition = 300;
            redefines maxPosition = 800;
        }

        state def ActuatorStateMachine {
            entry; then idle;

            state idle;
            state raising;
            state lowering;
            state fault;

            transition idle to raising when raiseRequested;
            transition idle to lowering when lowerRequested;
            transition raising to idle when heightReached;
            transition lowering to idle when heightReached;
            transition raising to fault when limitExceeded;
            transition lowering to fault when limitExceeded;
            transition fault to idle when resetRequested;
        }

        perform ActuatorStateMachine;
    }

    // ---- Part Definitions: Bed Sections ----
    part def BedSection {
        attribute sectionId : BedSectionId;
        attribute minAngle : AngleValue = 0 [deg];
        attribute maxAngle : AngleValue = 75 [deg];
        attribute currentAngle : AngleValue = 0 [deg];
        attribute targetAngle : AngleValue;
        attribute tiltRequested : Boolean = false;
        attribute angleReached : Boolean = false;
        attribute limitExceeded : Boolean = false;
        attribute resetRequested : Boolean = false;
        port sectionPort : MotorControlPort;

        part motor : ElectricMotor {
            redefines minPosition = 0;
            redefines maxPosition = 75;
        }

        state def SectionStateMachine {
            entry; then idle;

            state idle;
            state tilting;
            state fault;

            transition idle to tilting when tiltRequested;
            transition tilting to idle when angleReached;
            transition tilting to fault when limitExceeded;
            transition fault to idle when resetRequested;
        }

        perform SectionStateMachine;
    }

    // ---- Part Definition: Mattress ----
    part def Mattress {
        attribute length : Real = 2000 [mm];
        attribute width : Real = 900 [mm];
        attribute thickness : Real = 120 [mm];
        part pressureSensors : PressureSensor[16];

        connection sensorDataFlow connect pressureSensors.sensorPort to self;
    }

    // ---- Part Definition: Bed Frame ----
    part def BedFrame {
        part headSection : BedSection {
            redefines sectionId = BedSectionId::head;
        }

        part footSection : BedSection {
            redefines sectionId = BedSectionId::foot;
        }

        part linearActuator : LinearActuator;
        part mattress : Mattress;

        connection headMotorControl connect headSection.sectionPort to headSection.motor.controlPort;
        connection footMotorControl connect footSection.sectionPort to footSection.motor.controlPort;
        connection actuatorMotorControl connect linearActuator.actuatorPort to linearActuator.motor.controlPort;
    }

    // ---- Part Definition: Sensor Suite ----
    part def SensorSuite {
        attribute pressureSensorCount : Integer = 16;
        attribute loadCellCount : Integer = 4;
        attribute samplingInterval : TimeValue = 1 [s];

        part pressureSensors : PressureSensor[16];
        part loadCells : LoadCell[4];

        port dataPort : SensorDataPort;

        attribute currentPressureMap : PressureMap;
        attribute currentWeightReading : WeightReading;

        action def aggregatePressureData {
            in sensors : PressureSensor[16];
            out map : PressureMap;
        }

        action def aggregateWeightData {
            in cells : LoadCell[4];
            out reading : WeightReading;
        }

        action def computeMaxPressure {
            in map : PressureMap;
            out maxPressure : PressureValue;
        }

        perform aggregatePressureData {
            in sensors = pressureSensors;
            out map = currentPressureMap;
        }

        perform aggregateWeightData {
            in cells = loadCells;
            out reading = currentWeightReading;
        }

        perform computeMaxPressure {
            in map = currentPressureMap;
            out maxPressure = currentPressureMap.maxPressure;
        }

        connection pressureSensorFeeds connect pressureSensors.sensorPort to dataPort;
        connection loadCellFeeds connect loadCells.cellPort to dataPort;
    }

    // ---- Part Definition: Control Interface ----
    part def ControlInterface {
        port interfacePort : CaregiverInterfacePort;

        attribute displayBacklight : Boolean = true;
        attribute buttonCount : Integer = 8;

        action def receiveCommand {
            out cmd : CaregiverCommand;
        }

        action def displayStatus {
            in status : BedStatus;
        }

        action def displayAlert {
            in alertMsg : AlertMessage;
        }

        action def acknowledgeAlert {
            out acknowledged : Boolean;
        }

        perform receiveCommand;
        perform displayStatus;
        perform displayAlert;
        perform acknowledgeAlert;
    }

    // ---- Part Definition: Central Controller ----
    part def CentralController {
        port interfacePort : CaregiverInterfacePort;
        port headMotorPort : MotorControlPort;
        port footMotorPort : MotorControlPort;
        port actuatorPort : ActuatorControlPort;
        port sensorDataPort : SensorDataPort;
        port powerPort : PowerPort;

        attribute maxWeightCapacity : WeightValue = 250 [kg];
        attribute pressureThreshold : PressureValue = 32 [kPa];
        attribute pressureDurationThreshold : TimeValue = 7200 [s];
        attribute weightDropThreshold : WeightValue = 15 [kg];
        attribute weightDropTimeWindow : TimeValue = 5 [s];

        attribute currentConfig : BedConfiguration;
        attribute currentWeight : WeightValue;
        attribute currentPressureMap : PressureMap;
        attribute previousWeight : WeightValue;
        attribute weightStableTime : TimeValue;
        attribute highPressureDuration : TimeValue;
        attribute alertAcknowledged : Boolean = false;
        attribute resetRequested : Boolean = false;
        attribute emergencyStopRequested : Boolean = false;
        attribute patientExitDetected : Boolean = false;
        attribute pressureUlcerRiskDetected : Boolean = false;
        attribute weightExceededDetected : Boolean = false;

        action def processSensorData {
            in pressureMap : PressureMap;
            in weightReading : WeightReading;
            out processedWeight : WeightValue;
            out processedMap : PressureMap;
        }

        action def analyzePressureMap {
            in map : PressureMap;
            out riskAreas : Integer[*];
            out maxPressure : PressureValue;
        }

        action def detectPatientExit {
            in currentWeight : WeightValue;
            in previousWeight : WeightValue;
            in map : PressureMap;
            out exitDetected : Boolean;
        }

        action def checkSafetyLimits {
            in config : BedConfiguration;
            in weight : WeightValue;
            out withinLimits : Boolean;
            out limitType : AlertType;
        }

        action def generateAlert {
            in alertType : AlertType;
            in severity : AlertSeverity;
            in description : String;
            out alert : AlertMessage;
        }

        action def executeCommands {
            in command : CaregiverCommand;
            out headCommand : CaregiverCommand;
            out footCommand : CaregiverCommand;
            out heightCommand : CaregiverCommand;
        }

        action def updateHighPressureDuration {
            in maxPressure : PressureValue;
            in threshold : PressureValue;
            inout duration : TimeValue;
        }

        state def ControllerStateMachine {
            entry; then monitoring;

            state monitoring {
                entry; then processSensors;
                action processSensors;
                then evaluateSafety;
                action evaluateSafety;
                then executeCmds;
                action executeCmds;
                then monitoring;
            }

            state patientExitAlert {
                entry; then sendExitAlert;
                action sendExitAlert;
                then monitoring;
            }

            state pressureUlcerAlert {
                entry; then sendUlcerAlert;
                action sendUlcerAlert;
                then monitoring;
            }

            state weightExceededAlert {
                entry; then sendWeightAlert;
                action sendWeightAlert;
                then monitoring;
            }

            state emergencyStopState {
                entry; then haltAllMotors;
                action haltAllMotors;
            }

            transition monitoring to patientExitAlert when patientExitDetected;
            transition monitoring to pressureUlcerAlert when pressureUlcerRiskDetected;
            transition monitoring to weightExceededAlert when weightExceededDetected;
            transition monitoring to emergencyStopState when emergencyStopRequested;
            transition patientExitAlert to monitoring when alertAcknowledged;
            transition pressureUlcerAlert to monitoring when alertAcknowledged;
            transition weightExceededAlert to monitoring when alertAcknowledged;
            transition emergencyStopState to monitoring when resetRequested;
        }

        perform ControllerStateMachine;

        perform processSensorData {
            in pressureMap = currentPressureMap;
            in weightReading = sensorDataPort.weightReading;
            out processedWeight = currentWeight;
            out processedMap = currentPressureMap;
        }

        perform analyzePressureMap {
            in map = currentPressureMap;
        }

        perform detectPatientExit {
            in currentWeight = currentWeight;
            in previousWeight = previousWeight;
            in map = currentPressureMap;
            out exitDetected = patientExitDetected;
        }

        perform checkSafetyLimits {
            in config = currentConfig;
            in weight = currentWeight;
        }

        perform generateAlert;

        perform executeCommands {
            in command = interfacePort.command;
        }

        perform updateHighPressureDuration {
            in maxPressure = currentPressureMap.maxPressure;
            in threshold = pressureThreshold;
            inout duration = highPressureDuration;
        }
    }

    // ---- Part Definition: Power Supply ----
    part def PowerSupply {
        port powerPort : PowerPort;

        attribute inputVoltage : VoltageValue = 230 [V];
        attribute maxCurrent : CurrentValue = 10 [A];
        attribute currentDraw : CurrentValue;
        attribute powerStatus : PowerStatus;
        attribute powerOffRequested : Boolean = false;
        attribute powerOnRequested : Boolean = true;
        attribute overloadDetected : Boolean = false;
        attribute resetRequested : Boolean = false;

        state def PowerStateMachine {
            entry; then on;

            state on;
            state off;
            state fault;

            transition on to off when powerOffRequested;
            transition off to on when powerOnRequested;
            transition on to fault when overloadDetected;
            transition fault to off when resetRequested;
        }

        perform PowerStateMachine;
    }

    // ---- Main System Definition ----
    part def HospitalBed {
        attribute systemId : String;
        attribute manufacturer : String = "MedTech Systems";
        attribute modelNumber : String = "HBS-2024";

        part bedFrame : BedFrame;
        part sensorSuite : SensorSuite;
        part controller : CentralController;
        part controlInterface : ControlInterface;
        part powerSupply : PowerSupply;

        // Power distribution
        connection powerToController connect powerSupply.powerPort to controller.powerPort;
        connection powerToHeadMotor connect powerSupply.powerPort to bedFrame.headSection.motor.controlPort;
        connection powerToFootMotor connect powerSupply.powerPort to bedFrame.footSection.motor.controlPort;
        connection powerToActuatorMotor connect powerSupply.powerPort to bedFrame.linearActuator.motor.controlPort;

        // Sensor data to controller
        connection pressureDataToController connect sensorSuite.dataPort to controller.sensorDataPort;

        // Pressure sensors in mattress connected to sensor suite
        connection mattressSensorsToSuite connect bedFrame.mattress.pressureSensors.sensorPort to sensorSuite.pressureSensors.sensorPort;

        // Motor control from controller to bed sections
        connection headControl connect controller.headMotorPort to bedFrame.headSection.sectionPort;
        connection footControl connect controller.footMotorPort to bedFrame.footSection.sectionPort;
        connection actuatorControl connect controller.actuatorPort to bedFrame.linearActuator.actuatorPort;

        // Caregiver interface to controller
        connection caregiverInterface connect controlInterface.interfacePort to controller.interfacePort;
    }

    // ---- Requirement Definitions ----
    requirement def ShallProvideAdjustableHeadSection {
        subject bed : HospitalBed;
        objective {
            doc /* The bed shall provide an independently adjustable head section with angle range 0 to 75 degrees powered by an electric motor. */
        }
        require bed.bedFrame.headSection.minAngle == 0 [deg];
        require bed.bedFrame.headSection.maxAngle == 75 [deg];
    }

    requirement def ShallProvideAdjustableFootSection {
        subject bed : HospitalBed;
        objective {
            doc /* The bed shall provide an independently adjustable foot section with angle range 0 to 75 degrees powered by an electric motor. */
        }
        require bed.bedFrame.footSection.minAngle == 0 [deg];
        require bed.bedFrame.footSection.maxAngle == 75 [deg];
    }

    requirement def ShallProvideHeightAdjustment {
        subject bed : HospitalBed;
        objective {
            doc /* The bed shall provide height adjustment from 300 mm to 800 mm via a linear actuator system. */
        }
        require bed.bedFrame.linearActuator.minHeight == 300 [mm];
        require bed.bedFrame.linearActuator.maxHeight == 800 [mm];
    }

    requirement def ShallProvidePressureMapping {
        subject bed : HospitalBed;
        objective {
            doc /* The mattress shall contain an array of 16 pressure sensors that create a real-time pressure map of the patient body. */
        }
        require bed.sensorSuite.pressureSensorCount == 16;
    }

    requirement def ShallProvideWeightMeasurement {
        subject bed : HospitalBed;
        objective {
            doc /* The bed frame shall be equipped with 4 load cells working together as a scale to continuously measure patient weight. */
        }
        require bed.sensorSuite.loadCellCount == 4;
    }

    requirement def ShallDetectPatientExit {
        subject bed : HospitalBed;
        objective {
            doc /* The system shall detect patient exit attempts by sensing a sudden weight drop exceeding 15 kg combined with a pressure distribution change, and shall issue an immediate alert to staff. */
        }
        require bed.controller.weightDropThreshold == 15 [kg];
    }

    requirement def ShallAlertPressureUlcerRisk {
        subject bed : HospitalBed;
        objective {
            doc /* The system shall analyze the pressure map to identify prolonged pressure exceeding 32 kPa on specific areas for more than 2 hours and alert caregivers to reposition the patient. */
        }
        require bed.controller.pressureThreshold == 32 [kPa];
        require bed.controller.pressureDurationThreshold == 7200 [s];
    }

    requirement def ShallEnforceSafetyInterlocks {
        subject bed : HospitalBed;
        objective {
            doc /* The controller shall enforce safe mechanical limits for head angle, foot angle, and height, and shall monitor patient weight against the bed maximum capacity of 250 kg, generating an alert if exceeded. */
        }
        require bed.controller.maxWeightCapacity == 250 [kg];
        require bed.bedFrame.headSection.minAngle == 0 [deg];
        require bed.bedFrame.headSection.maxAngle == 75 [deg];
        require bed.bedFrame.footSection.minAngle == 0 [deg];
        require bed.bedFrame.footSection.maxAngle == 75 [deg];
        require bed.bedFrame.linearActuator.minHeight == 300 [mm];
        require bed.bedFrame.linearActuator.maxHeight == 800 [mm];
    }

    requirement def ShallProvideCaregiverInterface {
        subject bed : HospitalBed;
        objective {
            doc /* The bed shall provide a control interface through which caregivers can send adjustment commands and receive bed status, patient data, and alert messages. */
        }
        require bed.controlInterface.buttonCount == 8;
    }

    requirement def ShallBeElectricallyPowered {
        subject bed : HospitalBed;
        objective {
            doc /* The bed shall be powered by a standard electrical supply at 230 volts with maximum current draw of 10 amperes. */
        }
        require bed.powerSupply.inputVoltage == 230 [V];
        require bed.powerSupply.maxCurrent == 10 [A];
    }

    requirement def ShallCommunicateStatus {
        subject bed : HospitalBed;
        objective {
            doc /* The bed shall communicate its status, patient data, and any alerts back to the caregiver through its control interface. */
        }
        require bed.controller.interfacePort.defined;
    }

    // ---- System Instance and Satisfaction ----
    part hospitalBedInstance : HospitalBed {
        redefines systemId = "HBS-001";
    }

    satisfy ShallProvideAdjustableHeadSection by hospitalBedInstance;
    satisfy ShallProvideAdjustableFootSection by hospitalBedInstance;
    satisfy ShallProvideHeightAdjustment by hospitalBedInstance;
    satisfy ShallProvidePressureMapping by hospitalBedInstance;
    satisfy ShallProvideWeightMeasurement by hospitalBedInstance;
    satisfy ShallDetectPatientExit by hospitalBedInstance;
    satisfy ShallAlertPressureUlcerRisk by hospitalBedInstance;
    satisfy ShallEnforceSafetyInterlocks by hospitalBedInstance;
    satisfy ShallProvideCaregiverInterface by hospitalBedInstance;
    satisfy ShallBeElectricallyPowered by hospitalBedInstance;
    satisfy ShallCommunicateStatus by hospitalBedInstance;
}
