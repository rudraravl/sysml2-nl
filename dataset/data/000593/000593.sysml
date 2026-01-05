package DurableMedicalEquipmentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def PatientIdentifier :> String;
    attribute def OxygenFlowRate :> VolumeFlowRateValue;
    attribute def OxygenPurity :> Real;
    attribute def BatteryChargeLevel :> Real;
    attribute def OperatingHours :> DurationValue;
    attribute def AmbientTemperature :> ThermodynamicTemperatureValue;
    attribute def DeviceSerialNumber :> String;

    enum def SystemStatus {
        powerOff;
        standby;
        operational;
        alarm;
        maintenance;
        fault;
    }

    enum def AlarmCondition {
        lowOxygenPurity;
        lowBattery;
        highPressure;
        filterClogged;
        systemMalfunction;
        powerFailure;
    }

    item def AmbientAir {
        attribute oxygenContent : Real = 21.0;
        attribute nitrogenContent : Real = 78.0;
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }

    item def ConcentratedOxygen {
        attribute purity : OxygenPurity;
        attribute flowRate : OxygenFlowRate;
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }

    item def Patient {
        attribute patientID : PatientIdentifier;
        attribute prescribedFlowRate : OxygenFlowRate;
        attribute oxygenSaturation : Real;
        attribute respiratoryRate : Real;
    }

    port def AirIntakePort {
        in item ambientAir : AmbientAir;
    }

    port def OxygenOutputPort {
        out item concentratedOxygen : ConcentratedOxygen;
    }

    port def PowerInputPort {
        in attribute voltage : ISQ::VoltageValue;
        in attribute current : ElectricCurrentValue;
    }

    port def DiagnosticPort {
        out attribute status : SystemStatus;
        out attribute alarms : AlarmCondition[0..*];
        out attribute operatingTime : OperatingHours;
    }

    part def AirFilterAssembly {
        attribute filterEfficiency : Real = 99.5;
        attribute pressureDrop : PressureValue = 2.0 [SI::kPa];
        attribute replacementInterval : OperatingHours = 2000.0 [Time::h];
        attribute currentUsage : OperatingHours;
    }

    part def CompressorModule {
        attribute maxPressure : PressureValue = 200.0 [SI::kPa];
        attribute compressionRatio : Real = 3.5;
        attribute powerConsumption : PowerValue = 120.0 [SI::W];
        attribute operatingTemperature : ThermodynamicTemperatureValue;
        attribute motorSpeed : Real;
    }

    part def MolecularSieveUnit {
        attribute nitrogenAdsorptionCapacity : Real = 95.0;
        attribute cycleTime : DurationValue = 20.0 [Time::s];
        attribute regenerationPressure : PressureValue = 5.0 [SI::kPa];
        
        part sieveBedA : SieveBed {
            attribute bedVolume : VolumeValue = 0.8 [SI::L];
            attribute zeoliteType : String = "13X";
        }
        
        part sieveBedB : SieveBed {
            attribute bedVolume : VolumeValue = 0.8 [SI::L];
            attribute zeoliteType : String = "13X";
        }
    }

    part def SieveBed {
        attribute bedVolume : VolumeValue;
        attribute zeoliteType : String;
        attribute adsorptionEfficiency : Real = 98.0;
    }

    part def OxygenAccumulator {
        attribute tankCapacity : VolumeValue = 1.5 [SI::L];
        attribute currentVolume : VolumeValue;
        attribute storagePressure : PressureValue = 150.0 [SI::kPa];
        attribute oxygenPurity : OxygenPurity;
    }

    part def FlowRegulationSystem {
        attribute minFlowRate : OxygenFlowRate = 0.5 [SI::L/Time::min];
        attribute maxFlowRate : OxygenFlowRate = 5.0 [SI::L/Time::min];
        attribute currentFlowRate : OxygenFlowRate;
        attribute regulationAccuracy : Real = 0.1;
    }

    part def PowerSupplySystem {
        part acPowerAdapter : ACAdapter {
            attribute inputVoltage : ISQ::VoltageValue = 120.0 [SI::V];
            attribute outputVoltage : ISQ::VoltageValue = 24.0 [SI::V];
            attribute maxCurrent : ElectricCurrentValue = 6.0 [SI::A];
        }
        
        part batteryPack : RechargableBattery {
            attribute nominalVoltage : ISQ::VoltageValue = 24.0 [SI::V];
            attribute capacity : Real = 6000.0;
            attribute chargeLevel : BatteryChargeLevel;
            attribute cycleCount : Integer;
            attribute maxCycles : Integer = 500;
        }
        
        part chargingController : ChargeController {
            attribute chargingCurrent : ElectricCurrentValue = 2.0 [SI::A];
            attribute chargingVoltage : ISQ::VoltageValue = 28.8 [SI::V];
        }
    }

    part def ACAdapter;
    part def RechargableBattery;
    part def ChargeController;

    part def ControllerBoard {
        attribute processorType : String = "ARM Cortex-M4";
        attribute firmwareVersion : String = "v2.3.1";
        attribute currentStatus : SystemStatus;
        attribute activeAlarms : AlarmCondition[0..*];
    }

    part def SensorArray {
        part oxygenSensor : OxygenPuritySensor {
            attribute measurementRange : Real[2] = (0.0, 100.0);
            attribute accuracy : Real = 1.0;
        }
        
        part flowSensor : FlowRateSensor {
            attribute measurementRange : OxygenFlowRate[2] = (0.0 [SI::L/Time::min], 10.0 [SI::L/Time::min]);
            attribute accuracy : Real = 0.05;
        }
        
        part pressureSensor : PressureSensor {
            attribute measurementRange : PressureValue[2] = (0.0 [SI::kPa], 300.0 [SI::kPa]);
            attribute accuracy : Real = 2.0;
        }
        
        part temperatureSensor : TemperatureSensor {
            attribute measurementRange : ThermodynamicTemperatureValue[2] = (253.15 [SI::K], 323.15 [SI::K]);
            attribute accuracy : Real = 1.0;
        }
    }

    part def OxygenPuritySensor;
    part def FlowRateSensor;
    part def PressureSensor;
    part def TemperatureSensor;

    part def AlarmSubsystem {
        attribute audioAlarmVolume : Real = 85.0;
        attribute visualAlarmBrightness : Real = 100.0;
        attribute alarmHistory : AlarmCondition[0..*];
    }

    part def UserInterfacePanel {
        attribute displayType : String = "LCD 4.3 inch";
        attribute backlightLevel : Real = 80.0;
        attribute buttonCount : Integer = 6;
    }

    action def IntakeAmbientAir {
        in airSource : AmbientAir;
        out filteredAir : AmbientAir;
    }

    action def CompressAir {
        in filteredAir : AmbientAir;
        out compressedAir : AmbientAir;
    }

    action def SeparateOxygen {
        in compressedAir : AmbientAir;
        out oxygenRich : ConcentratedOxygen;
        out nitrogenWaste : AmbientAir;
    }

    action def AccumulateOxygen {
        in oxygenRich : ConcentratedOxygen;
        out storedOxygen : ConcentratedOxygen;
    }

    action def RegulateOxygenFlow {
        in storedOxygen : ConcentratedOxygen;
        in targetFlowRate : OxygenFlowRate;
        out regulatedOxygen : ConcentratedOxygen;
    }

    action def MonitorOxygenPurity {
        in oxygen : ConcentratedOxygen;
        out purityLevel : OxygenPurity;
        out isPurityAdequate : Boolean;
    }

    action def MonitorBatteryCharge {
        in chargeLevel : BatteryChargeLevel;
        out isChargeLow : Boolean;
    }

    action def ActivateAlarm {
        in alarmType : AlarmCondition;
        out alarmActive : Boolean;
    }

    action def OxygenGenerationProcess {
        first start;
        then merge continuousGeneration;
        
        then action intakeAir : IntakeAmbientAir {
            in airSource : AmbientAir;
            out filteredAir : AmbientAir;
        }
        
        then action compressAir : CompressAir {
            in filteredAir = intakeAir.filteredAir;
            out compressedAir : AmbientAir;
        }
        
        then action separateOxygen : SeparateOxygen {
            in compressedAir = compressAir.compressedAir;
            out oxygenRich : ConcentratedOxygen;
            out nitrogenWaste : AmbientAir;
        }
        
        then action accumulateOxygen : AccumulateOxygen {
            in oxygenRich = separateOxygen.oxygenRich;
            out storedOxygen : ConcentratedOxygen;
        }
        
        then action monitorPurity : MonitorOxygenPurity {
            in oxygen = accumulateOxygen.storedOxygen;
            out purityLevel : OxygenPurity;
            out isPurityAdequate : Boolean;
        }
        
        then decide;
            if monitorPurity.isPurityAdequate then deliverOxygen;
            if !monitorPurity.isPurityAdequate then triggerPurityAlarm;
        
        action deliverOxygen : RegulateOxygenFlow {
            in storedOxygen = accumulateOxygen.storedOxygen;
            in targetFlowRate : OxygenFlowRate;
            out regulatedOxygen : ConcentratedOxygen;
        }
        then continuousGeneration;
        
        action triggerPurityAlarm : ActivateAlarm {
            in alarmType = AlarmCondition::lowOxygenPurity;
            out alarmActive : Boolean;
        }
        then continuousGeneration;
    }

    state def PortableOxygenConcentratorStateMachine {
        entry; then off;
        
        state off;
        
        transition off_to_standby
            first off
            accept powerButtonPressed
            then standby;
        
        state standby;
        
        transition standby_to_operational
            first standby
            if systemCheckPassed
            then operational;
        
        transition standby_to_fault
            first standby
            if !systemCheckPassed
            then fault;
        
        state operational {
            state normalOperation;
            
            state lowBatteryWarning;
            
            transition normal_to_lowBattery
                first normalOperation
                if batteryChargeLevel < 20.0
                then lowBatteryWarning;
            
            transition lowBattery_to_normal
                first lowBatteryWarning
                if batteryChargeLevel >= 30.0
                then normalOperation;
        }
        
        transition operational_to_alarm
            first operational
            accept criticalAlarmCondition
            then alarm;
        
        state alarm;
        
        transition alarm_to_operational
            first alarm
            accept alarmAcknowledged
            if alarmConditionCleared
            then operational;
        
        transition alarm_to_fault
            first alarm
            if criticalSystemFailure
            then fault;
        
        state fault;
        
        transition fault_to_maintenance
            first fault
            accept maintenanceModeActivated
            then maintenance;
        
        state maintenance;
        
        transition maintenance_to_standby
            first maintenance
            accept maintenanceCompleted
            then standby;
        
        transition operational_to_off
            first operational
            accept powerButtonPressed
            then off;
        
        transition standby_to_off
            first standby
            accept powerButtonPressed
            then off;
    }

    part def PortableOxygenConcentrator {
        attribute serialNumber : DeviceSerialNumber;
        attribute totalMass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute noiseLevel : Real;
        
        port airIntake : AirIntakePort;
        port oxygenOutput : OxygenOutputPort;
        port powerInput : PowerInputPort;
        port diagnostics : DiagnosticPort;
        
        part airFilter : AirFilterAssembly {
            attribute :>> currentUsage = 500.0 [Time::h];
        }
        
        part compressor : CompressorModule {
            attribute :>> operatingTemperature = 313.15 [SI::K];
        }
        
        part sieveUnit : MolecularSieveUnit;
        
        part accumulator : OxygenAccumulator {
            attribute :>> currentVolume = 1.2 [SI::L];
            attribute :>> oxygenPurity = 93.0;
        }
        
        part flowRegulator : FlowRegulationSystem {
            attribute :>> currentFlowRate = 2.0 [SI::L/Time::min];
        }
        
        part powerSupply : PowerSupplySystem {
            part :>> batteryPack {
                attribute :>> chargeLevel = 75.0;
                attribute :>> cycleCount = 150;
            }
        }
        
        part controller : ControllerBoard {
            attribute :>> currentStatus = SystemStatus::operational;
        }
        
        part sensors : SensorArray;
        
        part alarmSystem : AlarmSubsystem;
        
        part userInterface : UserInterfacePanel;
        
        exhibit state deviceOperation : PortableOxygenConcentratorStateMachine;
        
        perform action oxygenGeneration : OxygenGenerationProcess;
    }

    requirement <'REQ-POC-001'> primaryOxygenDeliveryFunction {
        doc /* The portable oxygen concentrator shall continuously extract oxygen 
             * from ambient air and deliver concentrated oxygen at therapeutic levels 
             * to patients requiring supplemental oxygen therapy for respiratory conditions.
             */
        subject concentrator : PortableOxygenConcentrator;
    }

    requirement <'REQ-POC-002'> oxygenPuritySpecification {
        doc /* The system shall deliver oxygen at a purity level of at least 90 percent 
             * at all prescribed flow rates to ensure therapeutic effectiveness.
             */
        subject concentrator : PortableOxygenConcentrator;
        assert constraint {
            concentrator.accumulator.oxygenPurity >= 90.0
        }
    }

    requirement <'REQ-POC-003'> flowRateRange {
        doc /* The system shall provide adjustable oxygen flow rates from 0.5 to 5.0 
             * liters per minute to accommodate varying patient needs.
             */
        subject flowRegulator : FlowRegulationSystem;
        assert constraint {
            flowRegulator.currentFlowRate >= flowRegulator.minFlowRate and
            flowRegulator.currentFlowRate <= flowRegulator.maxFlowRate
        }
    }

    requirement <'REQ-POC-004'> batteryOperationDuration {
        doc /* The system shall operate on battery power for a minimum of 3 hours 
             * at a flow rate of 2 liters per minute to ensure patient mobility.
             */
        subject battery : RechargableBattery;
    }

    requirement <'REQ-POC-005'> alarmFunctionality {
        doc /* The system shall provide audible and visual alarms for low oxygen purity, 
             * low battery, high pressure, filter clogging, and system malfunctions.
             */
        subject alarmSystem : AlarmSubsystem;
    }

    requirement <'REQ-POC-006'> portabilityConstraint {
        doc /* The device total mass shall not exceed 3.0 kg to ensure portability 
             * and ease of transport for ambulatory patients.
             */
        subject concentrator : PortableOxygenConcentrator;
        assert constraint {
            concentrator.totalMass <= 3.0 [SI::kg]
        }
    }

    requirement <'REQ-POC-007'> operationalNoiseLimit {
        doc /* The system noise level shall not exceed 45 dBA at 1 meter distance 
             * during normal operation to minimize patient disturbance.
             */
        subject concentrator : PortableOxygenConcentrator;
        assert constraint {
            concentrator.noiseLevel <= 45.0
        }
    }

    part homeOxygenTherapySystem {
        part concentrator : PortableOxygenConcentrator {
            attribute :>> serialNumber = "POC-2024-7891";
            attribute :>> totalMass = 2.8 [SI::kg];
            attribute :>> dimensions = (25.0 [SI::cm], 18.0 [SI::cm], 10.0 [SI::cm]);
            attribute :>> noiseLevel = 42.0;
            
            part :>> accumulator {
                attribute :>> oxygenPurity = 93.5;
            }
            
            part :>> flowRegulator {
                attribute :>> currentFlowRate = 2.5 [SI::L/Time::min];
            }
            
            part :>> powerSupply {
                part :>> batteryPack {
                    attribute :>> chargeLevel = 85.0;
                }
            }
        }
        
        item patient : Patient {
            attribute :>> patientID = "PT-2024-5678";
            attribute :>> prescribedFlowRate = 2.5 [SI::L/Time::min];
            attribute :>> oxygenSaturation = 94.0;
            attribute :>> respiratoryRate = 16.0;
        }
        
        connection oxygenDeliveryPath
            connect concentrator.oxygenOutput to patient;
    }

    satisfy primaryOxygenDeliveryFunction by homeOxygenTherapySystem.concentrator;
    satisfy oxygenPuritySpecification by homeOxygenTherapySystem.concentrator;
    satisfy flowRateRange by homeOxygenTherapySystem.concentrator.flowRegulator;
    satisfy batteryOperationDuration by homeOxygenTherapySystem.concentrator.powerSupply.batteryPack;
    satisfy alarmFunctionality by homeOxygenTherapySystem.concentrator.alarmSystem;
    satisfy portabilityConstraint by homeOxygenTherapySystem.concentrator;
    satisfy operationalNoiseLimit by homeOxygenTherapySystem.concentrator;
}
