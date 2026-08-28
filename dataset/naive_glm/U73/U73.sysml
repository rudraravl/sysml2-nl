package ImpellaCardiacSupportSystem {

    import ScalarValues::*;

    // ============ Value Types ============
    attribute def RotationalSpeed :> Real { attribute unitName : String = "rpm"; }
    attribute def VolumetricFlowRate :> Real { attribute unitName : String = "L/min"; }
    attribute def Pressure :> Real { attribute unitName : String = "mmHg"; }
    attribute def Temperature :> Real { attribute unitName : String = "degC"; }
    attribute def ElectricCurrent :> Real { attribute unitName : String = "A"; }
    attribute def Voltage :> Real { attribute unitName : String = "V"; }
    attribute def Power :> Real { attribute unitName : String = "W"; }
    attribute def Dimensionless :> Real { attribute unitName : String = "1"; }
    attribute def TimeValue :> Real { attribute unitName : String = "s"; }
    attribute def Length :> Real { attribute unitName : String = "mm"; }
    attribute def Concentration :> Real { attribute unitName : String = "IU/mL"; }
    attribute def Volume :> Real { attribute unitName : String = "mL"; }

    // ============ Enumerations ============
    enum def SeverityKind { info; warning; critical; }
    enum def ClinicalPhase { standby; priming; ramping; fullSupport; weaning; faulted; }
    enum def AlarmCode { positionError; flowObstruction; motorOverTemp; motorOverCurrent; purgeLow; powerFault; communicationLoss; }

    // ============ Item Types ============
    item def Blood {
        attribute oxygenSaturation : Dimensionless;
        attribute hematocrit : Dimensionless;
    }

    item def PurgeFluid {
        attribute dextroseConcentration : Dimensionless;
        attribute heparinConcentration : Concentration;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : ElectricCurrent;
    }

    item def SensorReading {
        attribute value : Real;
        attribute valid : Boolean;
        attribute timestamp : TimeValue;
    }

    item def PressureReading :> SensorReading {
        :>> value : Pressure;
    }

    item def FlowReading :> SensorReading {
        :>> value : VolumetricFlowRate;
    }

    item def PositionReading :> SensorReading {
        :>> value : Dimensionless;
    }

    item def TemperatureReading :> SensorReading {
        :>> value : Temperature;
    }

    item def CurrentReading :> SensorReading {
        :>> value : ElectricCurrent;
    }

    item def AlarmEvent {
        attribute code : AlarmCode;
        attribute severity : SeverityKind;
        attribute message : String;
        attribute timestamp : TimeValue;
    }

    item def MotorCommand {
        attribute targetSpeed : RotationalSpeed;
        attribute enable : Boolean;
    }

    item def PurgeCommand {
        attribute targetPurgeFlow : VolumetricFlowRate;
        attribute enable : Boolean;
    }

    item def DisplayData {
        attribute flowRate : VolumetricFlowRate;
        attribute aorticPressure : Pressure;
        attribute ventricularPressure : Pressure;
        attribute motorSpeed : RotationalSpeed;
        attribute motorTemp : Temperature;
        attribute motorCurrent : ElectricCurrent;
        attribute purgeFlowRate : VolumetricFlowRate;
        attribute phase : ClinicalPhase;
    }

    // ============ Ports ============
    port def BloodPort {
        in item blood : Blood;
        out item blood : Blood;
    }

    port def PurgePort {
        in item purgeFluid : PurgeFluid;
        out item purgeFluid : PurgeFluid;
    }

    port def PowerPort {
        in item power : ElectricalPower;
        out item power : ElectricalPower;
    }

    port def SensorPort {
        in item reading : SensorReading;
        out item reading : SensorReading;
    }

    port def MotorCommandPort {
        in item command : MotorCommand;
        out item command : MotorCommand;
    }

    port def PurgeCommandPort {
        in item command : PurgeCommand;
        out item command : PurgeCommand;
    }

    port def AlarmPort {
        in item alarm : AlarmEvent;
        out item alarm : AlarmEvent;
    }

    port def DisplayPort {
        in item data : DisplayData;
        out item data : DisplayData;
    }

    // ============ Requirements ============
    requirement def CirculatorySupportRequirement {
        subject : ImpellaSystem;
        objective {
            doc "The system shall continuously pump blood from the left ventricle to the ascending aorta to reduce cardiac workload and improve systemic circulation.";
        }
    }

    requirement def TargetFlowRequirement {
        subject : ImpellaSystem;
        objective {
            doc "The system shall achieve and maintain a clinician-commanded target blood flow between 0.0 and 5.0 L/min.";
        }
    }

    requirement def PurgeIntegrityRequirement {
        subject : ImpellaSystem;
        objective {
            doc "The purge system shall continuously deliver dextrose-heparin fluid through the catheter channel to prevent blood ingress and clotting in the motor housing.";
        }
    }

    requirement def HemodynamicMonitoringRequirement {
        subject : ImpellaSystem;
        objective {
            doc "The system shall monitor aortic pressure, ventricular pressure, and blood flow rate.";
        }
    }

    requirement def PositionVerificationRequirement {
        subject : ImpellaSystem;
        objective {
            doc "The system shall verify catheter placement across the aortic valve and raise an alarm if malpositioned.";
        }
    }

    requirement def FlowObstructionDetectionRequirement {
        subject : ImpellaSystem;
        objective {
            doc "The system shall detect flow obstruction and raise a warning or critical alarm.";
        }
    }

    requirement def MotorProtectionRequirement {
        subject : ImpellaSystem;
        objective {
            doc "The system shall monitor motor temperature and current and alarm before potential motor failure.";
        }
    }

    requirement def ClinicalStateRequirement {
        subject : ImpellaSystem;
        objective {
            doc "The system shall operate through priming, ramping, fullSupport, and weaning clinical phases.";
        }
    }

    requirement def UserInterfaceRequirement {
        subject : ImpellaSystem;
        objective {
            doc "The console shall display flow rate, pressure, motor speed, motor temperature, purge flow, and alarms to the clinician.";
        }
    }

    // ============ Action Definitions ============
    action def ComputeMotorSpeed {
        in targetFlow : VolumetricFlowRate;
        in measuredFlow : VolumetricFlowRate;
        in motorTemp : Temperature;
        in motorCurrent : ElectricCurrent;
        out speedCommand : RotationalSpeed;
        doc "Closed-loop control action that computes the motor speed command to achieve target blood flow with safety derating.";
    }

    action def EvaluateAlarms {
        in positionReading : PositionReading;
        in motorTempReading : TemperatureReading;
        in motorCurrentReading : CurrentReading;
        in purgeFlowReading : FlowReading;
        in flowReading : FlowReading;
        in aorticPressureReading : PressureReading;
        in ventricularPressureReading : PressureReading;
        out alarms : AlarmEvent[*];
        doc "Evaluates sensor and motor status data to detect incorrect positioning, flow obstruction, purge failure, and motor fault conditions.";
    }

    action def RampMotorSpeed {
        in startSpeed : RotationalSpeed;
        in targetSpeed : RotationalSpeed;
        in rampRate : RotationalSpeed;
        out currentSpeed : RotationalSpeed;
        doc "Gradually adjusts motor speed toward the target at a controlled ramp rate.";
    }

    // ============ State Machine ============
    state def ClinicalStateMachine {
        attribute currentPhase : ClinicalPhase;
        attribute startPriming : Boolean;
        attribute primingComplete : Boolean;
        attribute targetFlowAchieved : Boolean;
        attribute weaningCommand : Boolean;
        attribute weaningComplete : Boolean;
        attribute faultDetected : Boolean;
        attribute faultCleared : Boolean;

        attribute targetSpeed : RotationalSpeed;
        attribute purgeFlowRate : VolumetricFlowRate;

        initial;
        state standby {
            attribute safeSpeed : RotationalSpeed = 0;
        }
        state priming {
            attribute primingPurgeFlow : VolumetricFlowRate = 0.1;
        }
        state ramping {
            attribute rampRate : RotationalSpeed = 500;
        }
        state fullSupport {
            attribute sustainedSpeed : RotationalSpeed;
        }
        state weaning {
            attribute weanRate : RotationalSpeed = 200;
        }
        state faulted {
            attribute emergencySpeed : RotationalSpeed = 0;
        }

        transition from initial to standby;
        transition from standby to priming when startPriming;
        transition from priming to ramping when primingComplete;
        transition from ramping to fullSupport when targetFlowAchieved;
        transition from fullSupport to weaning when weaningCommand;
        transition from weaning to standby when weaningComplete;
        transition from standby to faulted when faultDetected;
        transition from priming to faulted when faultDetected;
        transition from ramping to faulted when faultDetected;
        transition from fullSupport to faulted when faultDetected;
        transition from weaning to faulted when faultDetected;
        transition from faulted to standby when faultCleared;
    }

    // ============ Part Definitions ============
    part def CatheterAssembly {
        port ventricularInlet : BloodPort;
        port aorticOutlet : BloodPort;
        port pumpInlet : BloodPort;
        port pumpOutlet : BloodPort;
        port purgeIn : PurgePort;

        attribute catheterLength : Length;
        attribute inletDiameter : Length;
        attribute outletDiameter : Length;

        part catheterBody {
            attribute material : String = "polyurethane";
            attribute durometer : Integer;
        }
        part purgeLumen {
            port purgeIn : PurgePort;
            port purgeOut : PurgePort;
            connect purgeIn to purgeOut;
        }
        part inletCage {
            attribute poreSize : Length;
        }
        part outletCage {
            attribute poreSize : Length;
        }

        connect ventricularInlet to pumpInlet;
        connect pumpOutlet to aorticOutlet;
        connect purgeIn to purgeLumen.purgeIn;
    }

    part def MicroaxialPump {
        port bloodIn : BloodPort;
        port bloodOut : BloodPort;
        port powerIn : PowerPort;
        port commandIn : MotorCommandPort;
        port motorTempOut : SensorPort;
        port motorCurrentOut : SensorPort;

        attribute nominalSpeed : RotationalSpeed = 40000;
        attribute maxSpeed : RotationalSpeed = 50000;
        attribute minSpeed : RotationalSpeed = 0;
        attribute currentSpeed : RotationalSpeed;
        attribute powerConsumption : Power;
        attribute flowRate : VolumetricFlowRate;

        part impellerAssembly {
            attribute bladeCount : Integer = 6;
            attribute material : String = "titanium";
            attribute diameter : Length;
        }
        part motor {
            attribute statorWinding : String = "copper";
            attribute rotorType : String = "microaxial";
            attribute temperature : Temperature;
            attribute current : ElectricCurrent;
            attribute maxTemperature : Temperature = 45;
            attribute maxCurrent : ElectricCurrent = 5;
        }
        part motorHousing {
            attribute sealed : Boolean = true;
            attribute purgeChannelPresent : Boolean = true;
        }

        connect bloodIn to impellerAssembly;
        connect impellerAssembly to bloodOut;

        action pumpAction : ComputeMotorSpeed;
    }

    part def PurgeSystem {
        port purgeOut : PurgePort;
        port commandIn : PurgeCommandPort;
        port purgeFlowOut : SensorPort;

        attribute purgeFlowRate : VolumetricFlowRate;
        attribute reservoirVolume : Volume;
        attribute reservoirCapacity : Volume = 500;

        part reservoir {
            attribute capacity : Volume;
            attribute fluid : PurgeFluid;
            attribute remainingVolume : Volume;
        }
        part purgePump {
            attribute type : String = "peristaltic";
            attribute speed : RotationalSpeed;
        }
        part purgeLine {
            port purgeIn : PurgePort;
            port purgeOut : PurgePort;
            connect purgeIn to purgeOut;
        }

        connect reservoir to purgePump;
        connect purgePump to purgeOut;
        connect purgePump to purgeLine.purgeIn;
    }

    part def SensorSuite {
        port aorticPressure : SensorPort;
        port ventricularPressure : SensorPort;
        port flow : SensorPort;
        port position : SensorPort;

        part aorticPressureSensor {
            attribute range : Pressure;
            attribute accuracy : Pressure;
            attribute type : String = "piezoresistive";
        }
        part ventricularPressureSensor {
            attribute range : Pressure;
            attribute accuracy : Pressure;
            attribute type : String = "piezoresistive";
        }
        part flowSensor {
            attribute range : VolumetricFlowRate;
            attribute accuracy : VolumetricFlowRate;
            attribute type : String = "ultrasonic";
        }
        part positionSensor {
            attribute type : String = "electromagnetic";
            attribute confidence : Dimensionless;
        }
    }

    part def ControlAlgorithm {
        port aorticPressure : SensorPort;
        port ventricularPressure : SensorPort;
        port flow : SensorPort;
        port motorCommandOut : MotorCommandPort;
        port purgeCommandOut : PurgeCommandPort;
        port displayData : DisplayPort;

        attribute targetFlow : VolumetricFlowRate;
        attribute currentSpeed : RotationalSpeed;
        attribute proportionalGain : Real = 1000;
        attribute integralGain : Real = 10;
        attribute derivativeGain : Real = 50;
        attribute maxSpeed : RotationalSpeed = 50000;

        action computeSpeed : ComputeMotorSpeed;
        action rampSpeed : RampMotorSpeed;
    }

    part def AlarmEvaluator {
        port position : SensorPort;
        port motorTemp : SensorPort;
        port motorCurrent : SensorPort;
        port purgeFlow : SensorPort;
        port flow : SensorPort;
        port aorticPressure : SensorPort;
        port ventricularPressure : SensorPort;
        port alarmOut : AlarmPort;

        attribute tempThreshold : Temperature = 45;
        attribute currentThreshold : ElectricCurrent = 5;
        attribute minPurgeFlow : VolumetricFlowRate = 0.05;
        attribute positionConfidenceThreshold : Dimensionless = 0.8;
        attribute minFlowRate : VolumetricFlowRate = 0.1;

        action evaluate : EvaluateAlarms;
    }

    part def ConsoleController {
        port powerIn : PowerPort;
        port aorticPressureIn : SensorPort;
        port ventricularPressureIn : SensorPort;
        port flowIn : SensorPort;
        port positionIn : SensorPort;
        port motorTempIn : SensorPort;
        port motorCurrentIn : SensorPort;
        port purgeFlowIn : SensorPort;
        port motorCommand : MotorCommandPort;
        port purgeCommand : PurgeCommandPort;
        port displayOut : DisplayPort;
        port alarmOut : AlarmPort;

        attribute targetFlow : VolumetricFlowRate;
        attribute targetSpeed : RotationalSpeed;
        attribute currentPhase : ClinicalPhase;

        part controlAlgorithm : ControlAlgorithm;
        part alarmEvaluator : AlarmEvaluator;
        state stateManager : ClinicalStateMachine;

        connect aorticPressureIn to controlAlgorithm.aorticPressure;
        connect ventricularPressureIn to controlAlgorithm.ventricularPressure;
        connect flowIn to controlAlgorithm.flow;
        connect flowIn to alarmEvaluator.flow;
        connect aorticPressureIn to alarmEvaluator.aorticPressure;
        connect ventricularPressureIn to alarmEvaluator.ventricularPressure;
        connect positionIn to alarmEvaluator.position;
        connect motorTempIn to alarmEvaluator.motorTemp;
        connect motorCurrentIn to alarmEvaluator.motorCurrent;
        connect purgeFlowIn to alarmEvaluator.purgeFlow;
        connect controlAlgorithm.motorCommandOut to motorCommand;
        connect controlAlgorithm.purgeCommandOut to purgeCommand;
        connect controlAlgorithm.displayData to displayOut;
        connect alarmEvaluator.alarmOut to alarmOut;
    }

    part def UserInterface {
        port displayIn : DisplayPort;
        port alarmIn : AlarmPort;
        port displayOut : DisplayPort;
        port alarmOut : AlarmPort;

        part displayScreen {
            attribute resolution : String = "1024x768";
            attribute backlight : Boolean = true;
        }
        part alarmIndicator {
            attribute audible : Boolean = true;
            attribute visual : Boolean = true;
            attribute volume : Dimensionless;
        }
        part controlPanel {
            attribute buttonCount : Integer = 12;
            attribute targetFlowDial : Boolean = true;
        }

        connect displayIn to displayOut;
        connect alarmIn to alarmOut;
    }

    part def PowerSupply {
        port mainsIn : PowerPort;
        port motorPower : PowerPort;
        port controllerPower : PowerPort;

        attribute outputVoltage : Voltage = 24;
        attribute maxPower : Power = 100;
        attribute efficiency : Dimensionless = 0.9;

        part acDcConverter {
            attribute inputVoltage : Voltage = 120;
            attribute outputVoltage : Voltage = 24;
        }
        part batteryBackup {
            attribute capacity : Real = 200;
            attribute chargeLevel : Dimensionless;
            attribute outputVoltage : Voltage = 24;
        }

        connect mainsIn to acDcConverter;
        connect acDcConverter to motorPower;
        connect acDcConverter to controllerPower;
        connect batteryBackup to controllerPower;
    }

    part def ImpellaSystem {
        port patientBloodIn : BloodPort;
        port patientBloodOut : BloodPort;
        port mainsPower : PowerPort;
        port clinicianDisplay : DisplayPort;
        port clinicianAlarm : AlarmPort;

        attribute targetFlow : VolumetricFlowRate;
        attribute currentPhase : ClinicalPhase;
        attribute patientId : String;

        part catheter : CatheterAssembly;
        part pump : MicroaxialPump;
        part purge : PurgeSystem;
        part controller : ConsoleController;
        part sensors : SensorSuite;
        part ui : UserInterface;
        part power : PowerSupply;

        // Blood path: left ventricle -> catheter inlet -> pump -> catheter outlet -> aorta
        connect patientBloodIn to catheter.ventricularInlet;
        connect catheter.aorticOutlet to patientBloodOut;
        connect catheter.pumpInlet to pump.bloodIn;
        connect pump.bloodOut to catheter.pumpOutlet;

        // Purge path
        connect purge.purgeOut to catheter.purgeIn;

        // Power distribution
        connect mainsPower to power.mainsIn;
        connect power.motorPower to pump.powerIn;
        connect power.controllerPower to controller.powerIn;

        // Sensor signals to controller
        connect sensors.aorticPressure to controller.aorticPressureIn;
        connect sensors.ventricularPressure to controller.ventricularPressureIn;
        connect sensors.flow to controller.flowIn;
        connect sensors.position to controller.positionIn;
        connect pump.motorTempOut to controller.motorTempIn;
        connect pump.motorCurrentOut to controller.motorCurrentIn;
        connect purge.purgeFlowOut to controller.purgeFlowIn;

        // Control commands
        connect controller.motorCommand to pump.commandIn;
        connect controller.purgeCommand to purge.commandIn;

        // User interface
        connect controller.displayOut to ui.displayIn;
        connect controller.alarmOut to ui.alarmIn;
        connect ui.displayOut to clinicianDisplay;
        connect ui.alarmOut to clinicianAlarm;

        // Requirement satisfactions
        satisfy CirculatorySupportRequirement;
        satisfy TargetFlowRequirement;
        satisfy PurgeIntegrityRequirement;
        satisfy HemodynamicMonitoringRequirement;
        satisfy PositionVerificationRequirement;
        satisfy FlowObstructionDetectionRequirement;
        satisfy MotorProtectionRequirement;
        satisfy ClinicalStateRequirement;
        satisfy UserInterfaceRequirement;
    }

    // ============ Requirement Usages ============
    requirement circulatorySupport : CirculatorySupportRequirement {
        subject = ImpellaSystem;
    }
    requirement targetFlow : TargetFlowRequirement {
        subject = ImpellaSystem;
    }
    requirement purgeIntegrity : PurgeIntegrityRequirement {
        subject = ImpellaSystem;
    }
    requirement hemodynamicMonitoring : HemodynamicMonitoringRequirement {
        subject = ImpellaSystem;
    }
    requirement positionVerification : PositionVerificationRequirement {
        subject = ImpellaSystem;
    }
    requirement flowObstructionDetection : FlowObstructionDetectionRequirement {
        subject = ImpellaSystem;
    }
    requirement motorProtection : MotorProtectionRequirement {
        subject = ImpellaSystem;
    }
    requirement clinicalState : ClinicalStateRequirement {
        subject = ImpellaSystem;
    }
    requirement userInterface : UserInterfaceRequirement {
        subject = ImpellaSystem;
    }
}
