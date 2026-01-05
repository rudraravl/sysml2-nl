package ImpellaCardiacSupportSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def RotationalSpeedValue :> ISQ::FrequencyValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def PowerValue :> ISQ::PowerValue;

    enum def OperatingMode {
        off;
        standby;
        priming;
        ramping;
        fullSupport;
        weaning;
        alarm;
    }

    enum def AlarmLevel {
        none;
        advisory;
        warning;
        critical;
    }

    enum def CatheterPosition {
        optimal;
        suboptimal;
        malpositioned;
    }

    item def Blood {
        attribute oxygenSaturation : Real;
        attribute hematocrit : Real;
    }

    item def PurgeFluid {
        attribute dextrose : Real;
        attribute heparin : Real;
    }

    port def BloodFlowPort {
        in item bloodIn : Blood;
        out item bloodOut : Blood;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def PurgePort {
        in item purgeFluidIn : PurgeFluid;
        attribute purgeFlowRate : FlowRateValue;
        attribute purgePressure : PressureValue;
    }

    port def PowerPort {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
    }

    port def SensorDataPort {
        out attribute motorSpeed : RotationalSpeedValue;
        out attribute motorCurrent : ISQ::ElectricCurrentValue;
        out attribute motorTemperature : TemperatureValue;
        out attribute position : CatheterPosition;
    }

    port def ControlSignalPort {
        in attribute targetSpeed : RotationalSpeedValue;
        in attribute targetFlowRate : FlowRateValue;
    }

    part def MicroaxialMotor {
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute motorCurrent : ISQ::ElectricCurrentValue;
        attribute motorTemperature : TemperatureValue;
        attribute powerConsumption : PowerValue;

        port powerIn : PowerPort;
        port controlIn : ControlSignalPort;
        port sensorOut : SensorDataPort;

        action def SpinRotor {
            in targetSpeed : RotationalSpeedValue;
            out actualSpeed : RotationalSpeedValue;
        }
    }

    part def ImpellerAssembly {
        attribute bladeCount : Integer = 6;
        attribute impellerDiameter : ISQ::LengthValue;
        attribute generatedPressure : PressureValue;

        part motor : MicroaxialMotor;

        port bloodInlet : BloodFlowPort;
        port bloodOutlet : BloodFlowPort;

        action def PumpBlood {
            in motorSpeed : RotationalSpeedValue;
            in inletPressure : PressureValue;
            out outletPressure : PressureValue;
            out flowRate : FlowRateValue;
        }
    }

    part def CatheterShaft {
        attribute outerDiameter : ISQ::LengthValue;
        attribute length : ISQ::LengthValue;
        attribute flexibility : Real;

        part impeller : ImpellerAssembly;
        part purgeChannel;

        port proximalEnd;
        port distalEnd;
        port purgeIn : PurgePort;
    }

    part def PositionSensor {
        attribute detectedPosition : CatheterPosition;
        attribute signalStrength : Real;

        port sensorPort;
        port dataOut;

        action def DetectPosition {
            out position : CatheterPosition;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute accuracy : Real;

        port sensingPort;
        port dataOut;

        action def MeasurePressure {
            out pressure : PressureValue;
        }
    }

    part def FlowSensor {
        attribute measuredFlow : FlowRateValue;
        attribute accuracy : Real;

        port sensingPort;
        port dataOut;

        action def MeasureFlow {
            out flow : FlowRateValue;
        }
    }

    part def PurgeSystem {
        attribute purgeFlowRate : FlowRateValue;
        attribute purgePressure : PressureValue;
        attribute purgeInterval : ISQ::DurationValue;

        port purgeFluidReservoir;
        port purgeOutlet : PurgePort;

        action def DeliverPurgeFluid {
            in interval : ISQ::DurationValue;
            out flowRate : FlowRateValue;
        }
    }

    part def ControlAlgorithm {
        attribute currentMode : OperatingMode;
        attribute targetFlowRate : FlowRateValue;
        attribute targetMotorSpeed : RotationalSpeedValue;
        attribute alarmStatus : AlarmLevel;

        action def CalculateMotorSpeed {
            in desiredFlow : FlowRateValue;
            in currentFlow : FlowRateValue;
            in ventricularPressure : PressureValue;
            in aorticPressure : PressureValue;
            out commandedSpeed : RotationalSpeedValue;
        }

        action def EvaluateAlarms {
            in motorTemperature : TemperatureValue;
            in motorCurrent : ISQ::ElectricCurrentValue;
            in catheterPosition : CatheterPosition;
            in flowRate : FlowRateValue;
            out alarmLevel : AlarmLevel;
        }
    }

    part def ConsoleController {
        attribute displayedFlowRate : FlowRateValue;
        attribute displayedPressure : PressureValue;
        attribute operatingMode : OperatingMode;

        part algorithm : ControlAlgorithm;
        part powerSupply;
        part userInterface;
        part alarmModule;

        port sensorInputs;
        port motorControl : ControlSignalPort;
        port powerOutput : PowerPort;
        port userCommands;
        port alarmOutputs;
    }

    part def LeftVentricle {
        attribute pressure : PressureValue;
        attribute volume : ISQ::VolumeValue;
        attribute ejectionFraction : Real;

        port outflow : BloodFlowPort;
    }

    part def AscendingAorta {
        attribute pressure : PressureValue;
        attribute compliance : Real;

        port inflow : BloodFlowPort;
    }

    part def ImpellaDevice {
        attribute systemFlowRate : FlowRateValue;
        attribute systemMode : OperatingMode;
        attribute totalPowerConsumption : PowerValue;

        part catheter : CatheterShaft {
            attribute :>> outerDiameter = 3.7 [mm];
            attribute :>> length = 550.0 [mm];
        }

        part positionSensor : PositionSensor;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part purgeSystem : PurgeSystem {
            attribute :>> purgeFlowRate = 15.0 [mL/min];
            attribute :>> purgePressure = 300.0 [Pa];
        }
        part console : ConsoleController;

        part ventricle : LeftVentricle;
        part aorta : AscendingAorta;

        connect ventricle.outflow to catheter.impeller.bloodInlet;
        connect catheter.impeller.bloodOutlet to aorta.inflow;
        connect purgeSystem.purgeOutlet to catheter.purgeIn;
        connect console.powerOutput to catheter.impeller.motor.powerIn;
        connect console.motorControl to catheter.impeller.motor.controlIn;
        connect catheter.impeller.motor.sensorOut to console.sensorInputs;
        connect positionSensor.dataOut to console.sensorInputs;
        connect inletPressureSensor.dataOut to console.sensorInputs;
        connect outletPressureSensor.dataOut to console.sensorInputs;
        connect flowSensor.dataOut to console.sensorInputs;
    }

    action def MonitorHemodynamics {
        in ventricularPressure : PressureValue;
        in aorticPressure : PressureValue;
        in currentFlowRate : FlowRateValue;
        in catheterPosition : CatheterPosition;
        out hemodynamicStatus : Real;
    }

    action def AdjustPumpSpeed {
        in targetFlow : FlowRateValue;
        in currentFlow : FlowRateValue;
        in hemodynamicStatus : Real;
        out newMotorSpeed : RotationalSpeedValue;
    }

    action def VerifyPosition {
        in position : CatheterPosition;
        out positionValid : Boolean;
    }

    action def ManagePurge {
        in purgeInterval : ISQ::DurationValue;
        out purgeActive : Boolean;
    }

    action def HandleAlarm {
        in alarmLevel : AlarmLevel;
        out systemResponse : OperatingMode;
    }

    action def ProvideCirculatorySupport {
        first start;

        then action initialize {
            out systemReady : Boolean;
        }

        then action verifyPosition : VerifyPosition {
            in position;
            out positionValid;
        }

        then decide;
            if verifyPosition.positionValid then beginSupport;
            if !verifyPosition.positionValid then positionAlarm;

        action positionAlarm : HandleAlarm {
            in alarmLevel = AlarmLevel::critical;
        }
        then done;

        action beginSupport;
        then merge supportLoop;

        then action monitorHemodynamics : MonitorHemodynamics {
            in ventricularPressure;
            in aorticPressure;
            in currentFlowRate;
            in catheterPosition;
            out hemodynamicStatus;
        }

        then action adjustSpeed : AdjustPumpSpeed {
            in targetFlow;
            in currentFlow = monitorHemodynamics.currentFlowRate;
            in hemodynamicStatus = monitorHemodynamics.hemodynamicStatus;
            out newMotorSpeed;
        }

        then action managePurge : ManagePurge {
            in purgeInterval = 30.0 [s];
            out purgeActive;
        }

        then action evaluateAlarms : ControlAlgorithm::EvaluateAlarms {
            in motorTemperature;
            in motorCurrent;
            in catheterPosition;
            in flowRate;
            out alarmLevel;
        }

        then decide;
            if evaluateAlarms.alarmLevel == AlarmLevel::none then supportLoop;
            if evaluateAlarms.alarmLevel == AlarmLevel::advisory then supportLoop;
            if evaluateAlarms.alarmLevel == AlarmLevel::warning then supportLoop;
            if evaluateAlarms.alarmLevel == AlarmLevel::critical then emergencyShutdown;

        action emergencyShutdown : HandleAlarm {
            in alarmLevel = AlarmLevel::critical;
        }
        then done;
    }

    state def ImpellaOperationStateMachine {
        entry; then off;

        state off;
        accept at off then standby;

        state standby;
        accept at standby then priming;

        state priming {
            do action primeCatheter;
        }
        accept at priming then ramping;

        state ramping {
            do action rampUpMotor;
        }
        accept at ramping then fullSupport;

        state fullSupport {
            do action maintainSupport;
        }
        accept at fullSupport then weaning;
        accept at fullSupport then alarm;

        state weaning {
            do action reduceSupport;
        }
        accept at weaning then standby;
        accept at weaning then fullSupport;

        state alarm {
            do action handleCriticalAlarm;
        }
        accept at alarm then standby;
        accept at alarm then off;

        accept at standby then off;
        accept at alarm then done;
    }

    requirement def StakeholderRequirement;
    requirement def SystemRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;

    requirement <'REQ-STK-001'> provideVentricularSupport : StakeholderRequirement {
        doc /* The Impella system shall provide temporary mechanical circulatory 
             * support by actively pumping blood from the left ventricle into the 
             * ascending aorta to augment cardiac output in patients with acute 
             * heart failure or cardiogenic shock.
             */
        subject impellaDevice : ImpellaDevice;
    }

    requirement <'REQ-SYS-100'> flowRateCapability : PerformanceRequirement {
        doc /* The system shall provide adjustable blood flow rates between 
             * 2.5 and 5.0 liters per minute to accommodate varying degrees 
             * of hemodynamic support.
             */
        subject device :>> ImpellaDevice;

        assert constraint {
            device.systemFlowRate >= 2.5 [L/min] and 
            device.systemFlowRate <= 5.0 [L/min]
        }
    }

    requirement <'REQ-SYS-101'> motorSpeedRange : PerformanceRequirement {
        doc /* The microaxial motor shall operate at rotational speeds 
             * between 20,000 and 50,000 RPM to achieve target flow rates.
             */
        subject motor :>> ImpellaDevice::catheter::impeller::motor;

        assert constraint {
            motor.rotationalSpeed >= 20000.0 [Hz] and 
            motor.rotationalSpeed <= 50000.0 [Hz]
        }
    }

    requirement <'REQ-SYS-102'> pressureGeneration : PerformanceRequirement {
        doc /* The impeller assembly shall generate sufficient pressure 
             * differential to overcome aortic pressure and maintain forward flow.
             */
        subject impeller :>> ImpellaDevice::catheter::impeller;

        assert constraint {
            impeller.generatedPressure >= 8000.0 [Pa]
        }
    }

    requirement <'REQ-SAF-200'> continuousPurge : SafetyRequirement {
        doc /* The purge system shall continuously deliver purge fluid at 
             * a minimum rate of 10 mL/min to prevent thrombus formation 
             * within the catheter and motor housing.
             */
        subject purge :>> ImpellaDevice::purgeSystem;

        assert constraint {
            purge.purgeFlowRate >= 10.0 [mL/min]
        }
    }

    requirement <'REQ-SAF-201'> positionMonitoring : SafetyRequirement {
        doc /* The system shall continuously monitor catheter position 
             * to ensure proper placement across the aortic valve with 
             * the inlet in the left ventricle and outlet in the ascending aorta.
             */
        subject sensor :>> ImpellaDevice::positionSensor;

        require provideVentricularSupport;
    }

    requirement <'REQ-SAF-202'> hemolysisMinimization : SafetyRequirement {
        doc /* The pump design shall minimize blood trauma and hemolysis 
             * during operation through optimized impeller geometry and 
             * controlled rotational speeds.
             */
        subject impeller :>> ImpellaDevice::catheter::impeller;
    }

    requirement <'REQ-SAF-203'> alarmSystem : SafetyRequirement {
        doc /* The system shall provide real-time alarm monitoring for 
             * critical conditions including malposition, motor failure, 
             * flow obstruction, and excessive hemolysis.
             */
        subject controller :>> ImpellaDevice::console;

        assert constraint {
            controller.algorithm.alarmStatus != AlarmLevel::none
        }
    }

    part impellaCP : ImpellaDevice {
        attribute :>> systemFlowRate = 4.0 [L/min];
        attribute :>> systemMode = OperatingMode::standby;

        part :>> catheter {
            part :>> impeller {
                attribute :>> generatedPressure = 10000.0 [Pa];

                part :>> motor {
                    attribute :>> rotationalSpeed = 33000.0 [Hz];
                    attribute :>> powerConsumption = 25.0 [W];
                    attribute :>> motorTemperature = 310.0 [K];
                }
            }
        }

        part :>> purgeSystem {
            attribute :>> purgeFlowRate = 15.0 [mL/min];
            attribute :>> purgePressure = 40000.0 [Pa];
        }

        part :>> console {
            attribute :>> displayedFlowRate = 4.0 [L/min];
            attribute :>> operatingMode = OperatingMode::standby;

            part :>> algorithm {
                attribute :>> currentMode = OperatingMode::standby;
                attribute :>> targetFlowRate = 4.0 [L/min];
                attribute :>> targetMotorSpeed = 33000.0 [Hz];
            }
        }

        perform action circulatorySupport : ProvideCirculatorySupport;
    }

    satisfy provideVentricularSupport by impellaCP;
    satisfy flowRateCapability by impellaCP;
    satisfy motorSpeedRange by impellaCP.catheter.impeller.motor;
    satisfy pressureGeneration by impellaCP.catheter.impeller;
    satisfy continuousPurge by impellaCP.purgeSystem;
    satisfy positionMonitoring by impellaCP.positionSensor;
    satisfy hemolysisMinimization by impellaCP.catheter.impeller;
    satisfy alarmSystem by impellaCP.console;
}
