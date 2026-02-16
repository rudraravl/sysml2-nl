package MedipinesRespiratorySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OxygenConcentration :> Real {
        doc /* Fraction of inspired oxygen (FiO2), range 0.21 to 1.0 */
    }
    
    attribute def CO2Concentration :> Real {
        doc /* End-tidal CO2 concentration, typically 4-6% */
    }
    
    attribute def RespiratoryRate :> FrequencyValue {
        doc /* Breaths per minute */
    }
    
    attribute def TidalVolume :> VolumeValue {
        doc /* Volume of air per breath */
    }
    
    attribute def GasFlowRate :> VolumeFlowRateValue {
        doc /* Gas flow rate */
    }
    
    attribute def GasPressure :> PressureValue {
        doc /* Gas pressure */
    }
    
    item def RespiratoryGasMixture {
        attribute o2Fraction : OxygenConcentration;
        attribute co2Fraction : CO2Concentration;
        attribute flowRate : GasFlowRate;
        attribute pressure : GasPressure;
        attribute temperature : TemperatureValue;
    }
    
    item def PatientRespiratoryData {
        attribute respiratoryRate : RespiratoryRate;
        attribute tidalVolume : TidalVolume;
        attribute minuteVentilation : GasFlowRate;
        attribute peakInspiratoryPressure : GasPressure;
        attribute oxygenSaturation : Real;
    }
    
    item def VentilationParameters {
        attribute targetRate : RespiratoryRate;
        attribute targetVolume : TidalVolume;
        attribute targetFiO2 : OxygenConcentration;
        attribute peepLevel : GasPressure;
        attribute inspiratoryTime : TimeValue;
    }
    
    item def AlarmCondition {
        attribute alarmType : String;
        attribute severity : String;
        attribute timestamp : TimeValue;
        attribute value : Real;
    }
    
    port def GasSupplyPort {
        in item gasSupply : RespiratoryGasMixture;
    }
    
    port def GasDeliveryPort {
        out item gasDelivery : RespiratoryGasMixture;
    }
    
    port def PatientCircuitPort {
        inout item patientGas : RespiratoryGasMixture;
        inout item patientData : PatientRespiratoryData;
    }
    
    port def ControlPort {
        in item parameters : VentilationParameters;
        out item status : PatientRespiratoryData;
        out item alarms : AlarmCondition;
    }
    
    port def PowerPort {
        in item power : PowerValue;
    }
    
    part def OxygenBlender {
        attribute blendRatio : Real;
        port airInlet : GasSupplyPort;
        port oxygenInlet : GasSupplyPort;
        port mixedGasOutlet : GasDeliveryPort;
        
        perform action blendGases {
            in airFlow : GasFlowRate;
            in o2Flow : GasFlowRate;
            in targetFiO2 : OxygenConcentration;
            out mixedGas : RespiratoryGasMixture;
        }
    }
    
    part def FlowSensor {
        attribute calibrationFactor : Real;
        port gasInput : GasSupplyPort;
        port gasOutput : GasDeliveryPort;
        port dataOutput : ControlPort;
        
        perform action measureFlow {
            in gas : RespiratoryGasMixture;
            out flowRate : GasFlowRate;
            out volume : VolumeValue;
        }
    }
    
    part def PressureSensor {
        attribute sensitivity : Real;
        port measurementPoint : PatientCircuitPort;
        port dataOutput : ControlPort;
        
        perform action measurePressure {
            in gas : RespiratoryGasMixture;
            out pressure : GasPressure;
        }
    }
    
    part def CO2Sensor {
        attribute responseTime : TimeValue;
        port sampleInput : PatientCircuitPort;
        port dataOutput : ControlPort;
        
        perform action measureCO2 {
            in expiredGas : RespiratoryGasMixture;
            out co2Level : CO2Concentration;
        }
    }
    
    part def VentilatorValve {
        attribute position : Real;
        port gasInput : GasSupplyPort;
        port gasOutput : GasDeliveryPort;
        port control : ControlPort;
        port power : PowerPort;
        
        perform action regulateFlow {
            in commandedPosition : Real;
            in inputGas : RespiratoryGasMixture;
            out outputGas : RespiratoryGasMixture;
        }
    }
    
    part def PatientCircuit {
        attribute compliance : Real;
        attribute resistance : Real;
        port ventilatorConnection : PatientCircuitPort;
        port patientConnection : PatientCircuitPort;
        
        perform action deliverBreath {
            in inspiratoryGas : RespiratoryGasMixture;
            out deliveredGas : RespiratoryGasMixture;
        }
    }
    
    part def ControlProcessor {
        attribute controlMode : String;
        port sensorInputs : ControlPort;
        port valveOutputs : ControlPort;
        port userInterface : ControlPort;
        port power : PowerPort;
        
        perform action controlVentilation {
            in parameters : VentilationParameters;
            in patientData : PatientRespiratoryData;
            out valveCommands : Real;
            out alarms : AlarmCondition;
        }
    }
    
    part def AlarmSystem {
        attribute alarmHistory : AlarmCondition[*];
        port alarmInput : ControlPort;
        port alarmOutput : ControlPort;
        port power : PowerPort;
        
        perform action evaluateAlarms {
            in patientData : PatientRespiratoryData;
            in limits : VentilationParameters;
            out activeAlarms : AlarmCondition[*];
        }
    }
    
    part def UserInterface {
        attribute displayMode : String;
        port controlInput : ControlPort;
        port displayOutput : ControlPort;
        port power : PowerPort;
        
        perform action displayStatus {
            in patientData : PatientRespiratoryData;
            in alarms : AlarmCondition[*];
        }
    }
    
    action def InitializeSystem {
        in powerLevel : PowerValue;
        out systemReady : Boolean;
    }
    
    action def PerformSelfTest {
        out testResult : Boolean;
        out diagnostics : String;
    }
    
    action def DeliverInspiratoryPhase {
        in parameters : VentilationParameters;
        in blendedGas : RespiratoryGasMixture;
        out deliveredVolume : TidalVolume;
        out peakPressure : GasPressure;
    }
    
    action def MonitorExpiratoryPhase {
        in expiredGas : RespiratoryGasMixture;
        out tidalVolume : TidalVolume;
        out endTidalCO2 : CO2Concentration;
    }
    
    action def AdjustVentilationParameters {
        in currentData : PatientRespiratoryData;
        in targetParameters : VentilationParameters;
        out adjustedParameters : VentilationParameters;
    }
    
    action def HandleAlarmCondition {
        in alarm : AlarmCondition;
        out response : String;
    }
    
    state def VentilatorOperatingStates {
        private attribute systemStatus : String;
        private attribute breathPhase : String;
        private attribute breathTimer : TimeValue;
        private attribute breathPeriod : TimeValue;
        private attribute targetVolume : TidalVolume;
        
        entry; then powerOff;
        
        state powerOff;
        
        transition powerOn
            first powerOff
            accept powerCommand : Boolean
            if powerCommand
            then initializing;
        
        state initializing {
            do action init : InitializeSystem;
            do action selfTest : PerformSelfTest;
        }
        
        transition initComplete
            first initializing
            if selfTest.testResult
            then standby;
        
        transition initFailed
            first initializing
            if not selfTest.testResult
            then fault;
        
        state standby;
        
        transition startVentilation
            first standby
            accept startCommand : Boolean
            if startCommand
            then ventilating;
        
        state ventilating {
            state inspiration {
                do action inspire : DeliverInspiratoryPhase;
            }
            
            transition inspToExp
                first inspiration
                if inspire.deliveredVolume >= targetVolume
                then expiration;
            
            state expiration {
                do action expire : MonitorExpiratoryPhase;
            }
            
            transition expToInsp
                first expiration
                if breathTimer >= breathPeriod
                then inspiration;
        }
        
        transition ventToStandby
            first ventilating
            accept stopCommand : Boolean
            if stopCommand
            then standby;
        
        transition anyToFault
            first ventilating
            accept criticalAlarm : AlarmCondition
            if criticalAlarm.severity == "Critical"
            then fault;
        
        state fault {
            do action handleFault : HandleAlarmCondition;
        }
        
        transition faultToStandby
            first fault
            accept resetCommand : Boolean
            if resetCommand and handleFault.response == "Resolved"
            then standby;
    }
    
    part def MedipinesVentilator {
        doc /* 
            Medipines is an advanced mechanical ventilator system designed to provide 
            life-sustaining respiratory support to patients who cannot breathe adequately 
            on their own. Its primary function is to deliver precise, controlled volumes 
            of oxygen-enriched air to the patient's lungs at appropriate pressures and 
            rates, while continuously monitoring respiratory parameters and ensuring 
            patient safety through comprehensive alarm systems.
            
            The system automatically adjusts gas delivery based on programmed parameters 
            and real-time patient feedback, maintaining optimal oxygenation and ventilation 
            while minimizing the risk of ventilator-induced lung injury.
        */
        
        part blender : OxygenBlender {
            :>> blendRatio = 0.5;
        }
        
        part inspiratoryFlowSensor : FlowSensor {
            :>> calibrationFactor = 1.0;
        }
        
        part expiratoryFlowSensor : FlowSensor {
            :>> calibrationFactor = 1.0;
        }
        
        part airwayPressureSensor : PressureSensor {
            :>> sensitivity = 0.1;
        }
        
        part co2Monitor : CO2Sensor {
            :>> responseTime = 0.2 [SI::s];
        }
        
        part inspiratoryValve : VentilatorValve {
            :>> position = 0.0;
        }
        
        part expiratoryValve : VentilatorValve {
            :>> position = 1.0;
        }
        
        part circuit : PatientCircuit {
            :>> compliance = 50.0;
            :>> resistance = 5.0;
        }
        
        part controller : ControlProcessor {
            :>> controlMode = "Volume Control";
        }
        
        part alarmMgr : AlarmSystem;
        
        part display : UserInterface {
            :>> displayMode = "Normal";
        }
        
        connect blender.mixedGasOutlet to inspiratoryFlowSensor.gasInput;
        connect inspiratoryFlowSensor.gasOutput to inspiratoryValve.gasInput;
        connect inspiratoryValve.gasOutput to circuit.ventilatorConnection;
        connect circuit.patientConnection to expiratoryValve.gasInput;
        connect expiratoryValve.gasOutput to expiratoryFlowSensor.gasInput;
        
        binding airwayPressureSensor.measurementPoint to circuit.ventilatorConnection;
        binding co2Monitor.sampleInput to circuit.patientConnection;
        
        binding inspiratoryFlowSensor.dataOutput to controller.sensorInputs;
        binding expiratoryFlowSensor.dataOutput to controller.sensorInputs;
        binding airwayPressureSensor.dataOutput to controller.sensorInputs;
        binding co2Monitor.dataOutput to controller.sensorInputs;
        
        binding controller.valveOutputs to inspiratoryValve.control;
        binding controller.valveOutputs to expiratoryValve.control;
        
        binding controller.sensorInputs to alarmMgr.alarmInput;
        binding alarmMgr.alarmOutput to display.controlInput;
        binding controller.userInterface to display.controlInput;
        
        perform action operateVentilator {
            first start;
            then action initialize : InitializeSystem;
            then merge ventilationCycle;
            
            action ventilationCycle {
                first action setParameters {
                    out params : VentilationParameters;
                }
                then action blendGas {
                    in targetFiO2 : OxygenConcentration;
                    out mixedGas : RespiratoryGasMixture;
                }
                then action deliverBreath : DeliverInspiratoryPhase {
                    in parameters = setParameters.params;
                    in blendedGas = blendGas.mixedGas;
                }
                then action monitorExpiration : MonitorExpiratoryPhase;
                then action checkAlarms {
                    in limits : VentilationParameters;
                    out activeAlarms : AlarmCondition[*];
                }
                then decide;
                    if checkAlarms.activeAlarms->size() > 0 then handleAlarm;
                    else adjustParams;
                
                action handleAlarm : HandleAlarmCondition {
                    in alarm = checkAlarms.activeAlarms->at(1);
                }
                then ventilationCycle;
                
                action adjustParams : AdjustVentilationParameters {
                    in targetParameters = setParameters.params;
                }
                then ventilationCycle;
            }
        }
    }
    
    part medipinesUnit : MedipinesVentilator {
        exhibit stateMachine : VentilatorOperatingStates;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'REQ-MED-001'> primaryFunction : FunctionalRequirement {
        doc /* 
            The Medipines ventilator shall provide controlled mechanical ventilation 
            to patients requiring respiratory support, delivering precise tidal volumes 
            at specified respiratory rates with adjustable oxygen concentrations.
        */
    }
    
    requirement <'REQ-MED-002'> tidalVolumeAccuracy : PerformanceRequirement {
        doc /* 
            The system shall deliver tidal volumes with an accuracy of ±10% or ±10 mL, 
            whichever is greater, across the range of 50 mL to 2000 mL.
        */
    }
    
    requirement <'REQ-MED-003'> oxygenConcentrationAccuracy : PerformanceRequirement {
        doc /* 
            The system shall maintain FiO2 within ±3% of the set value across the 
            range of 21% to 100% oxygen.
        */
    }
    
    requirement <'REQ-MED-004'> pressureMonitoring : SafetyRequirement {
        doc /* 
            The system shall continuously monitor airway pressure and activate alarms 
            if pressure exceeds safe limits (typically 40 cmH2O peak pressure).
        */
    }
    
    requirement <'REQ-MED-005'> alarmResponse : SafetyRequirement {
        doc /* 
            The system shall detect alarm conditions within 5 seconds and provide 
            audible and visual alerts within 2 seconds of detection.
        */
        require pressureMonitoring;
    }
    
    requirement <'REQ-MED-006'> backupVentilation : SafetyRequirement {
        doc /* 
            The system shall provide backup ventilation mode if patient-triggered 
            breaths are not detected within a specified apnea interval.
        */
    }
    
    requirement systemRequirements {
        require primaryFunction;
        require tidalVolumeAccuracy;
        require oxygenConcentrationAccuracy;
        require pressureMonitoring;
        require alarmResponse;
        require backupVentilation;
    }
}
