package TransdermalContinuousOxygenTherapySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OxygenConcentration :> Real {
        doc /* Oxygen concentration as percentage of total gas mixture */
    }
    
    attribute def OxygenFlowRate :> VolumeFlowRateValue;
    
    attribute def SkinTemperature :> TemperatureValue;
    
    attribute def OxygenPressure :> PressureValue;
    
    attribute def BloodOxygenSaturation :> Real {
        doc /* Blood oxygen saturation percentage (SpO2) */
    }
    
    attribute def TherapyDuration :> TimeValue;
    
    item def MedicalOxygen {
        attribute concentration : OxygenConcentration;
        attribute pressure : OxygenPressure;
        attribute purity : Real;
    }
    
    item def TransdermalPatchAssembly {
        attribute activeArea : AreaValue;
        attribute permeabilityCoefficient : Real;
        attribute appliedPressure : OxygenPressure;
    }
    
    item def PatientPhysiologicalData {
        attribute skinTemp : SkinTemperature;
        attribute bloodSaturation : BloodOxygenSaturation;
        attribute absorptionRate : OxygenFlowRate;
    }
    
    item def ControlCommand {
        attribute targetFlowRate : OxygenFlowRate;
        attribute enableDelivery : Boolean;
        attribute pressureSetpoint : OxygenPressure;
    }
    
    item def StartTherapyCommand;
    item def PauseTherapyCommand;
    item def ResumeTherapyCommand;
    item def FaultClearedCommand;
    
    port def OxygenSupplyPort {
        out item oxygenSupply : MedicalOxygen;
    }
    
    port def OxygenDeliveryPort {
        in item oxygenInput : MedicalOxygen;
        out attribute deliveryRate : OxygenFlowRate;
    }
    
    port def PhysiologicalMonitorPort {
        out item patientData : PatientPhysiologicalData;
    }
    
    port def ControlInterfacePort {
        in item controlSignal : ControlCommand;
        out attribute statusFeedback : Boolean;
    }
    
    part def OxygenConcentratorUnit {
        doc /* Generates medical-grade oxygen from ambient air */
        
        attribute outputConcentration : OxygenConcentration;
        attribute outputPressure : OxygenPressure;
        attribute operatingPower : PowerValue;
        
        port oxygenOutput : OxygenSupplyPort;
        
        action def ConcentrateOxygen {
            in ambientAir : Real;
            out medicalOxygen : MedicalOxygen;
        }
    }
    
    part def OxygenReservoirTank {
        doc /* Stores concentrated oxygen at controlled pressure */
        
        attribute storageCapacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute tankPressure : OxygenPressure;
        
        port oxygenInlet : OxygenDeliveryPort;
        port oxygenOutlet : OxygenSupplyPort;
    }
    
    part def PressureRegulatorValve {
        doc /* Regulates oxygen pressure for safe transdermal delivery */
        
        attribute inputPressure : OxygenPressure;
        attribute outputPressure : OxygenPressure;
        attribute regulationAccuracy : Real;
        
        port highPressureInput : OxygenDeliveryPort;
        port regulatedOutput : OxygenSupplyPort;
        port controlInterface : ControlInterfacePort;
    }
    
    part def FlowControlModule {
        doc /* Controls oxygen flow rate based on therapy requirements */
        
        attribute setpointFlowRate : OxygenFlowRate;
        attribute measuredFlowRate : OxygenFlowRate;
        attribute flowAccuracy : Real;
        
        port oxygenInput : OxygenDeliveryPort;
        port oxygenOutput : OxygenSupplyPort;
        port controlInterface : ControlInterfacePort;
    }
    
    part def TransdermalDeliveryPatch {
        doc /* Delivers oxygen through skin via specialized membrane */
        
        attribute patchArea : AreaValue;
        attribute membraneThickness : LengthValue;
        attribute deliveryEfficiency : Real;
        attribute skinContactQuality : Real;
        
        port oxygenInput : OxygenDeliveryPort;
        port skinInterface : PhysiologicalMonitorPort;
    }
    
    part def PhysiologicalSensorArray {
        doc /* Monitors patient skin temperature and oxygen absorption */
        
        attribute sensorAccuracy : Real;
        attribute samplingRate : FrequencyValue;
        
        port monitoringInterface : PhysiologicalMonitorPort;
        
        action def MeasureSkinTemperature {
            out temperature : SkinTemperature;
        }
        
        action def MeasureBloodSaturation {
            out saturation : BloodOxygenSaturation;
        }
    }
    
    part def TherapyControlUnit {
        doc /* Central controller managing therapy delivery and safety */
        
        attribute targetSaturation : BloodOxygenSaturation;
        attribute currentSaturation : BloodOxygenSaturation;
        attribute therapyActive : Boolean;
        attribute safetyLimitTemp : SkinTemperature;
        attribute safetyLimitPressure : OxygenPressure;
        attribute systemSelfTestPassed : Boolean;
        attribute sensorsCalibrated : Boolean;
        attribute saturationBelowTarget : Boolean;
        attribute absorptionRateChanged : Boolean;
        attribute targetSaturationAchieved : Boolean;
        attribute therapyDurationExpired : Boolean;
        attribute skinTemperatureExceeded : Boolean;
        attribute pressureLimitExceeded : Boolean;
        attribute hyperoxiaDetected : Boolean;
        attribute componentFailure : Boolean;
        attribute faultResolved : Boolean;
        
        port sensorInput : PhysiologicalMonitorPort;
        port flowControlOutput : ControlInterfacePort;
        port pressureControlOutput : ControlInterfacePort;
        
        exhibit state therapyStateMachine : TherapyControlStateMachine;
    }
    
    part def PowerSupplyModule {
        doc /* Provides electrical power to all system components */
        
        attribute batteryCapacity : EnergyValue;
        attribute remainingCharge : EnergyValue;
        attribute outputVoltage : Real;
    }
    
    requirement def SystemFunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    requirement def ReliabilityRequirement;
    
    requirement <'TCOT-FR-001'> primaryTherapyFunction : SystemFunctionalRequirement {
        doc /* 
            The system shall deliver continuous oxygen therapy transdermally 
            to maintain patient blood oxygen saturation at therapeutic levels.
        */
        
        subject tcotSystem;
        
        assume constraint patientSkinIntact {
            doc /* Patient skin integrity is suitable for transdermal delivery */
        }
        
        require constraint continuousOxygenDelivery {
            doc /* System shall maintain continuous oxygen delivery during active therapy */
        }
        
        require constraint therapeuticSaturationMaintenance {
            doc /* System shall maintain blood oxygen saturation between 92% and 98% */
        }
    }
    
    requirement <'TCOT-FR-002'> closedLoopControl : SystemFunctionalRequirement {
        doc /* 
            The system shall implement closed-loop control based on real-time 
            physiological monitoring to optimize oxygen delivery.
        */
        
        require constraint continuousMonitoring {
            doc /* System shall continuously monitor patient physiological parameters */
        }
        
        require constraint adaptiveFlowControl {
            doc /* System shall adjust oxygen flow rate based on measured saturation */
        }
    }
    
    requirement <'TCOT-SF-001'> skinSafetyRequirement : SafetyRequirement {
        doc /* 
            The system shall prevent skin damage from excessive temperature 
            or pressure during therapy delivery.
        */
        
        require constraint temperatureSafetyLimit {
            doc /* Skin contact temperature shall remain between 30°C and 38°C */
        }
        
        require constraint pressureSafetyLimit {
            doc /* Applied oxygen pressure shall not exceed 45 kPa */
        }
        
        require constraint automaticShutdown {
            doc /* System shall automatically cease delivery if safety limits are exceeded */
        }
    }
    
    requirement <'TCOT-SF-002'> oxygenSafetyRequirement : SafetyRequirement {
        doc /* 
            The system shall prevent oxygen toxicity by limiting maximum 
            delivered oxygen concentration and duration.
        */
        
        require constraint concentrationLimit {
            doc /* Delivered oxygen concentration shall not exceed 95% */
        }
        
        require constraint hyperoxiaPrevention {
            doc /* System shall cease delivery if blood saturation exceeds 98% */
        }
    }
    
    requirement <'TCOT-PF-001'> deliveryPerformance : PerformanceRequirement {
        doc /* 
            The system shall deliver oxygen at specified flow rates with 
            required accuracy and response time.
        */
        
        require constraint flowRateRange {
            doc /* System shall support flow rates from 0.5 to 5.0 L/min */
        }
        
        require constraint flowRateAccuracy {
            doc /* Flow rate accuracy shall be within ±5% of setpoint */
        }
        
        require constraint responseTime {
            doc /* System shall adjust flow rate within 30 seconds of setpoint change */
        }
    }
    
    requirement <'TCOT-PF-002'> operationalDuration : PerformanceRequirement {
        doc /* 
            The system shall support continuous operation for extended 
            therapy sessions on battery power.
        */
        
        require constraint minimumOperatingTime {
            doc /* System shall operate continuously for minimum 8 hours on full battery */
        }
        
        require constraint batteryIndicator {
            doc /* System shall provide remaining battery capacity indication */
        }
    }
    
    requirement <'TCOT-RL-001'> systemReliability : ReliabilityRequirement {
        doc /* 
            The system shall maintain high reliability with fault detection 
            and graceful degradation capabilities.
        */
        
        require constraint faultDetection {
            doc /* System shall detect and report component failures within 10 seconds */
        }
        
        require constraint failsafeOperation {
            doc /* System shall enter safe state upon critical component failure */
        }
    }
    
    action def MonitorPatientPhysiology {
        in sensorData : PatientPhysiologicalData;
        out skinTempStatus : Boolean;
        out saturationStatus : Boolean;
        out absorptionRateStatus : Boolean;
    }
    
    action def CalculateRequiredFlow {
        in currentSaturation : BloodOxygenSaturation;
        in targetSaturation : BloodOxygenSaturation;
        in absorptionRate : OxygenFlowRate;
        out requiredFlowRate : OxygenFlowRate;
    }
    
    action def AdjustDeliveryParameters {
        in requiredFlow : OxygenFlowRate;
        in safetyStatus : Boolean;
        out flowCommand : ControlCommand;
        out pressureCommand : ControlCommand;
    }
    
    action def DeliverTransdermalOxygen {
        in oxygenSupply : MedicalOxygen;
        in patchEfficiency : Real;
        out deliveredOxygen : OxygenFlowRate;
    }
    
    action def ManageTherapySession {
        doc /* Primary action orchestrating complete therapy delivery cycle */
        
        first start;
        
        then action initializeSystem {
            doc /* Verify all components operational and establish baseline readings */
        }
        
        then action performSelfTest {
            doc /* Execute system self-test and safety verification */
        }
        
        then merge therapyControlLoop;
        
        loop action activeTherapy {
            action monitorPatient : MonitorPatientPhysiology {
                in sensorData;
                out skinTempStatus;
                out saturationStatus;
                out absorptionRateStatus;
            }
            
            then decide;
                if monitorPatient.skinTempStatus and monitorPatient.saturationStatus 
                    then calculateFlow;
                if not monitorPatient.skinTempStatus or not monitorPatient.saturationStatus 
                    then emergencyShutdown;
            
            action calculateFlow : CalculateRequiredFlow {
                in currentSaturation = monitorPatient.sensorData.bloodSaturation;
                in targetSaturation;
                in absorptionRate = monitorPatient.sensorData.absorptionRate;
                out requiredFlowRate;
            }
            
            then action adjustParameters : AdjustDeliveryParameters {
                in requiredFlow = calculateFlow.requiredFlowRate;
                in safetyStatus = monitorPatient.skinTempStatus;
                out flowCommand;
                out pressureCommand;
            }
            
            then action deliverOxygen : DeliverTransdermalOxygen {
                in oxygenSupply;
                in patchEfficiency;
                out deliveredOxygen;
            }
            
            then decide;
                if deliverOxygen.deliveredOxygen > 0.0 and 
                   monitorPatient.saturationStatus then therapyControlLoop;
                if deliverOxygen.deliveredOxygen <= 0.0 or 
                   not monitorPatient.saturationStatus then completeTherapy;
                   
        } until activeTherapy.monitorPatient.sensorData.bloodSaturation >= 98.0;
        
        action emergencyShutdown {
            doc /* Immediate cessation of oxygen delivery due to safety violation */
        }
        
        then action completeTherapy {
            doc /* Controlled therapy termination and system shutdown */
        }
        
        then done;
    }
    
    state def TherapyControlStateMachine {
        doc /* State machine governing therapy delivery lifecycle */
        
        entry; then standby;
        
        state standby {
            doc /* System powered and ready but not delivering therapy */
            entry action {
                doc /* Disable oxygen delivery and monitor system status */
            }
        }
        
        accept StartTherapyCommand;
        transition standby_to_initialization
            first standby
            then initialization;
        
        state initialization {
            doc /* System performing startup checks and calibration */
            entry action {
                doc /* Execute self-test and verify sensor calibration */
            }
        }
        
        transition initialization_to_active
            first initialization
            then activeDelivery;
        
        transition initialization_to_fault
            first initialization
            then faultState;
        
        state activeDelivery {
            doc /* System actively delivering oxygen therapy */
            
            state monitoring {
                doc /* Continuous monitoring of patient physiological parameters */
                entry action {
                    doc /* Sample sensors and update patient data */
                }
            }
            
            state regulating {
                doc /* Adjusting delivery parameters based on feedback */
                entry action {
                    doc /* Calculate and apply flow and pressure adjustments */
                }
            }
            
            state delivering {
                doc /* Oxygen flowing through transdermal patch */
                entry action {
                    doc /* Maintain oxygen delivery at regulated parameters */
                }
            }
            
            transition monitoring_to_regulating
                first monitoring
                then regulating;
            
            transition regulating_to_delivering
                first regulating
                then delivering;
            
            transition delivering_to_monitoring
                first delivering
                then monitoring;
        }
        
        accept PauseTherapyCommand;
        transition active_to_paused
            first activeDelivery
            then paused;
        
        state paused {
            doc /* Therapy temporarily suspended by operator */
            entry action {
                doc /* Reduce oxygen flow to minimum safe level */
            }
        }
        
        accept ResumeTherapyCommand;
        transition paused_to_active
            first paused
            then activeDelivery;
        
        transition active_to_completed
            first activeDelivery
            then completed;
        
        state completed {
            doc /* Therapy session completed successfully */
            entry action {
                doc /* Gradually reduce oxygen delivery and log session data */
            }
        }
        
        transition completed_to_standby
            first completed
            then standby;
        
        state emergencyShutdown {
            doc /* Emergency state requiring immediate delivery cessation */
            entry action {
                doc /* Immediately close all valves and alert operator */
            }
        }
        
        transition emergency_to_fault
            first emergencyShutdown
            then faultState;
        
        state faultState {
            doc /* System fault requiring service intervention */
            entry action {
                doc /* Log fault details and disable therapy capability */
            }
        }
        
        accept FaultClearedCommand;
        transition fault_to_standby
            first faultState
            then standby;
    }
    
    part tcotSystem : TransdermalContinuousOxygenTherapySystem {
        doc /* 
            Complete Transdermal Continuous Oxygen Therapy System
            
            Primary Function:
            This system delivers continuous oxygen therapy through the patient's skin 
            using a specialized transdermal delivery mechanism. The system generates 
            medical-grade oxygen from ambient air, stores it at controlled pressure, 
            and delivers it through a transdermal patch that enables oxygen absorption 
            through the skin barrier.
            
            The therapy operates through closed-loop control that continuously monitors 
            patient blood oxygen saturation, skin temperature, and oxygen absorption rate. 
            Based on real-time physiological feedback, the system automatically adjusts 
            oxygen flow rate and delivery pressure to maintain therapeutic blood oxygen 
            levels while ensuring patient safety.
            
            This non-invasive approach provides an alternative to traditional respiratory 
            oxygen delivery methods, particularly beneficial for patients who cannot 
            tolerate nasal cannulas or face masks, or who require supplemental oxygenation 
            during specific medical procedures or recovery periods.
        */
        
        attribute systemActive : Boolean = false;
        attribute therapyStartTime : TimeValue;
        attribute totalOxygenDelivered : VolumeValue;
        attribute cumulativeTherapyDuration : TimeValue;
        
        part concentrator : OxygenConcentratorUnit {
            attribute :>> outputConcentration = 93.0;
            attribute :>> outputPressure = 150.0;
        }
        
        part reservoir : OxygenReservoirTank {
            attribute :>> storageCapacity = 5.0;
            attribute :>> currentVolume = 4.5;
            attribute :>> tankPressure = 140.0;
        }
        
        part pressureRegulator : PressureRegulatorValve {
            attribute :>> inputPressure = 140.0;
            attribute :>> outputPressure = 35.0;
            attribute :>> regulationAccuracy = 0.98;
        }
        
        part flowController : FlowControlModule {
            attribute :>> setpointFlowRate = 2.5;
            attribute :>> flowAccuracy = 0.95;
        }
        
        part deliveryPatch : TransdermalDeliveryPatch {
            attribute :>> patchArea = 50.0;
            attribute :>> deliveryEfficiency = 0.82;
            attribute :>> skinContactQuality = 0.95;
        }
        
        part sensorArray : PhysiologicalSensorArray {
            attribute :>> sensorAccuracy = 0.97;
            attribute :>> samplingRate = 1.0;
        }
        
        part controller : TherapyControlUnit {
            attribute :>> targetSaturation = 95.0;
            attribute :>> therapyActive = false;
            attribute :>> safetyLimitTemp = 38.0;
            attribute :>> safetyLimitPressure = 45.0;
            attribute :>> systemSelfTestPassed = true;
            attribute :>> sensorsCalibrated = true;
            attribute :>> saturationBelowTarget = false;
            attribute :>> absorptionRateChanged = false;
            attribute :>> targetSaturationAchieved = false;
            attribute :>> therapyDurationExpired = false;
            attribute :>> skinTemperatureExceeded = false;
            attribute :>> pressureLimitExceeded = false;
            attribute :>> hyperoxiaDetected = false;
            attribute :>> componentFailure = false;
            attribute :>> faultResolved = false;
        }
        
        part powerSupply : PowerSupplyModule {
            attribute :>> batteryCapacity = 50.0;
            attribute :>> remainingCharge = 45.0;
            attribute :>> outputVoltage = 12.0;
        }
        
        connection concentratorToReservoir 
            connect concentrator.oxygenOutput to reservoir.oxygenInlet;
        
        connection reservoirToRegulator 
            connect reservoir.oxygenOutlet to pressureRegulator.highPressureInput;
        
        connection regulatorToFlowController 
            connect pressureRegulator.regulatedOutput to flowController.oxygenInput;
        
        connection flowControllerToPatch 
            connect flowController.oxygenOutput to deliveryPatch.oxygenInput;
        
        connection patchToSensors 
            connect deliveryPatch.skinInterface to sensorArray.monitoringInterface;
        
        connection sensorsToController 
            connect sensorArray.monitoringInterface to controller.sensorInput;
        
        connection controllerToFlowController 
            connect controller.flowControlOutput to flowController.controlInterface;
        
        connection controllerToPressureRegulator 
            connect controller.pressureControlOutput to pressureRegulator.controlInterface;
        
        perform action therapyManagement : ManageTherapySession {
            doc /* Primary therapy management and delivery coordination */
        }
        
        satisfy primaryTherapyFunction;
        satisfy closedLoopControl;
        satisfy skinSafetyRequirement;
        satisfy oxygenSafetyRequirement;
        satisfy deliveryPerformance;
        satisfy operationalDuration;
        satisfy systemReliability;
    }
    
    part def TransdermalContinuousOxygenTherapySystem {
        doc /* 
            System Definition: Transdermal Continuous Oxygen Therapy System
            
            A medical device system that provides non-invasive oxygen supplementation 
            through transdermal delivery, utilizing closed-loop physiological monitoring 
            and adaptive flow control to maintain therapeutic blood oxygen saturation 
            levels safely and effectively.
        */
    }
}
