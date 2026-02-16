package AdvancedAirwaySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PressureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def OxygenConcentrationValue :> Real;
    attribute def DiameterValue :> LengthValue;
    
    enum def AirwayStatus {
        unobstructed;
        partiallyObstructed;
        fullyObstructed;
        secured;
    }
    
    enum def VentilationMode {
        spontaneous;
        assisted;
        controlled;
    }
    
    item def RespiratoryGas {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute oxygenConcentration : OxygenConcentrationValue;
        attribute volume : VolumeValue;
    }
    
    port def GasFlowPort {
        inout gas : RespiratoryGas;
    }
    
    port def MonitoringPort {
        out pressure : PressureValue;
        out saturation : OxygenConcentrationValue;
        out flowRate : FlowRateValue;
    }
    
    port def ControlPort {
        in targetPressure : PressureValue;
        in targetVolume : VolumeValue;
        in ventilationMode : VentilationMode;
    }
    
    part def CuffSystem {
        attribute cuffPressure : PressureValue;
        attribute cuffDiameter : DiameterValue;
        attribute isInflated : Boolean;
        
        port inflationPort;
        port pressureMonitorPort;
    }
    
    part def TubeBody {
        attribute innerDiameter : DiameterValue;
        attribute outerDiameter : DiameterValue;
        attribute tubeLength : LengthValue;
        attribute material : String;
        
        port proximalEnd : GasFlowPort;
        port distalEnd : GasFlowPort;
    }
    
    part def VentilationConnector {
        attribute connectorType : String;
        attribute sealIntegrity : Real;
        
        port ventilatorInterface : GasFlowPort;
        port tubeInterface : GasFlowPort;
    }
    
    part def PressureSensor {
        attribute currentPressure : PressureValue;
        attribute maxPressure : PressureValue;
        attribute minPressure : PressureValue;
        
        port sensingPort;
        port dataOutput : MonitoringPort;
    }
    
    part def OxygenSensor {
        attribute currentSaturation : OxygenConcentrationValue;
        attribute targetSaturation : OxygenConcentrationValue;
        
        port sensingPort;
        port dataOutput : MonitoringPort;
    }
    
    part def FlowSensor {
        attribute currentFlow : FlowRateValue;
        attribute peakFlow : FlowRateValue;
        
        port sensingPort;
        port dataOutput : MonitoringPort;
    }
    
    part def ControlUnit {
        attribute ventilationMode : VentilationMode;
        attribute alarmEnabled : Boolean;
        attribute targetTidalVolume : VolumeValue;
        attribute targetRespiratoryRate : Real;
        
        port sensorInput : MonitoringPort;
        port controlOutput : ControlPort;
        port userInterface;
    }
    
    action def AssessAirway {
        in patientCondition;
        out airwayPatency : AirwayStatus;
        out requiresIntubation : Boolean;
    }
    
    action def InsertAirwayDevice {
        in airwayDevice;
        in patientAnatomy;
        out insertionSuccessful : Boolean;
        out devicePosition : String;
    }
    
    action def InflateCuff {
        in targetPressure : PressureValue;
        inout cuffSystem : CuffSystem;
        out achievedPressure : PressureValue;
        out sealEstablished : Boolean;
    }
    
    action def MonitorVentilation {
        in oxygenLevel : OxygenConcentrationValue;
        in airwayPressure : PressureValue;
        in flowRate : FlowRateValue;
        out ventilationAdequate : Boolean;
        out adjustmentNeeded : Boolean;
    }
    
    action def AdjustVentilationParameters {
        in currentFlow : FlowRateValue;
        in currentPressure : PressureValue;
        in targetSaturation : OxygenConcentrationValue;
        out newFlowRate : FlowRateValue;
        out newPressure : PressureValue;
        out newVolume : VolumeValue;
    }
    
    action def ManageAdvancedAirway {
        first start;
        then merge continueMonitoring;
        
        then action assess : AssessAirway;
        then decide;
            if assess.requiresIntubation then insert;
            if !assess.requiresIntubation then monitor;
        
        action insert : InsertAirwayDevice;
        then action inflateCuff : InflateCuff;
        then merge continueMonitoring;
        
        then action monitor : MonitorVentilation;
        then decide;
            if monitor.adjustmentNeeded then adjust;
            if !monitor.adjustmentNeeded then continueMonitoring;
        
        action adjust : AdjustVentilationParameters;
        then continueMonitoring;
    }
    
    state def AirwayManagementLifecycle {
        entry; then initial;
        
        state initial;
        transition initial_to_assessment
            first initial
            then assessment;
        
        state assessment {
            entry; then evaluatePatient;
            state evaluatePatient;
        }
        
        transition assessment_to_insertion
            first assessment
            accept at assessment.evaluatePatient
            then insertion;
        
        transition assessment_to_monitoring
            first assessment
            accept at assessment.evaluatePatient
            then monitoring;
        
        state insertion {
            entry; then positionDevice;
            state positionDevice;
            then secureCuff;
            state secureCuff;
        }
        
        transition insertion_to_secured
            first insertion
            accept at insertion.secureCuff
            then secured;
        
        state secured {
            entry; then confirmPlacement;
            state confirmPlacement;
        }
        
        transition secured_to_monitoring
            first secured
            then monitoring;
        
        state monitoring {
            entry; then continuousMonitor;
            state continuousMonitor;
            do action monitorParameters : MonitorVentilation;
        }
        
        transition monitoring_to_adjusting
            first monitoring
            accept at monitoring.continuousMonitor
            then adjusting;
        
        state adjusting {
            entry; then modifySettings;
            state modifySettings;
        }
        
        transition adjusting_to_monitoring
            first adjusting
            then monitoring;
        
        transition monitoring_to_emergency
            first monitoring
            then emergency;
        
        state emergency {
            entry; then initiateEmergencyProtocol;
            state initiateEmergencyProtocol;
        }
        
        transition emergency_to_monitoring
            first emergency
            accept at emergency.initiateEmergencyProtocol
            then monitoring;
    }
    
    part def AdvancedAirway {
        attribute deviceType : String;
        attribute deviceSize : DiameterValue;
        attribute isSecured : Boolean;
        
        part tubeBody : TubeBody {
            attribute :>> innerDiameter = 7.5 [mm];
            attribute :>> outerDiameter = 10.0 [mm];
            attribute :>> tubeLength = 300 [mm];
            attribute :>> material = "medical-grade PVC";
        }
        
        part cuffSystem : CuffSystem {
            attribute :>> cuffPressure = 25;
            attribute :>> cuffDiameter = 25 [mm];
            attribute :>> isInflated = false;
        }
        
        part ventilationConnector : VentilationConnector {
            attribute :>> connectorType = "15mm ISO standard";
            attribute :>> sealIntegrity = 0.98;
        }
        
        part pressureSensor : PressureSensor {
            attribute :>> maxPressure = 40;
            attribute :>> minPressure = 0;
        }
        
        part oxygenSensor : OxygenSensor {
            attribute :>> targetSaturation = 95.0;
        }
        
        part flowSensor : FlowSensor {
            attribute :>> peakFlow = 60;
        }
        
        part controlUnit : ControlUnit {
            attribute :>> ventilationMode = VentilationMode::assisted;
            attribute :>> alarmEnabled = true;
            attribute :>> targetTidalVolume = 500;
            attribute :>> targetRespiratoryRate = 12;
        }
        
        connection cuffToPressureSensor connect 
            cuffSystem.pressureMonitorPort to pressureSensor.sensingPort;
        
        connection pressureSensorToControl connect 
            pressureSensor.dataOutput to controlUnit.sensorInput;
        
        connection oxygenSensorToControl connect 
            oxygenSensor.dataOutput to controlUnit.sensorInput;
        
        connection flowSensorToControl connect 
            flowSensor.dataOutput to controlUnit.sensorInput;
        
        connection ventilatorToConnector connect 
            ventilationConnector.tubeInterface to tubeBody.proximalEnd;
        
        perform action manageAirway : ManageAdvancedAirway;
        
        exhibit state airwayLifecycle : AirwayManagementLifecycle;
    }
    
    part advancedAirwaySystem : AdvancedAirway {
        attribute :>> deviceType = "endotracheal tube with integrated monitoring";
        attribute :>> deviceSize = 7.5 [mm];
        attribute :>> isSecured = false;
        
        part :>> tubeBody {
            attribute :>> innerDiameter = 7.5 [mm];
            attribute :>> outerDiameter = 10.0 [mm];
            attribute :>> tubeLength = 300 [mm];
        }
        
        part :>> cuffSystem {
            attribute :>> cuffDiameter = 25 [mm];
            attribute :>> cuffPressure = 25;
        }
        
        part :>> controlUnit {
            attribute :>> ventilationMode = VentilationMode::assisted;
            attribute :>> targetTidalVolume = 500;
            attribute :>> targetRespiratoryRate = 12;
        }
    }
    
    requirement <'REQ-AA-001'> primaryFunction {
        doc /* The advanced airway system shall establish and maintain 
             * a secure, patent airway to enable effective mechanical 
             * ventilation and oxygenation of patients with compromised 
             * respiratory function or inability to protect their airway.
             */
        subject airway :> advancedAirwaySystem;
    }
    
    requirement <'REQ-AA-002'> secureAirwayPath {
        doc /* The system shall provide a continuous, unobstructed 
             * pathway for bidirectional gas exchange between the 
             * ventilation source and the patient's lungs.
             */
        subject airway :> advancedAirwaySystem;
    }
    
    requirement <'REQ-AA-003'> preventAspiration {
        doc /* The cuff system shall create an effective seal to 
             * prevent aspiration of gastric contents, secretions, 
             * or foreign material into the lower respiratory tract.
             */
        subject cuff :> advancedAirwaySystem.cuffSystem;
        
        assert constraint cuffPressureRange {
            cuff.cuffPressure >= 20 and 
            cuff.cuffPressure <= 30
        }
    }
    
    requirement <'REQ-AA-004'> maintainOxygenation {
        doc /* The system shall facilitate adequate oxygenation with 
             * oxygen saturation maintained at or above 92 percent.
             */
        subject sensor :> advancedAirwaySystem.oxygenSensor;
        
        assert constraint oxygenationTarget {
            sensor.currentSaturation >= 92.0
        }
    }
    
    requirement <'REQ-AA-005'> monitorVentilationParameters {
        doc /* The system shall continuously monitor airway pressure, 
             * gas flow rate, and oxygen saturation to ensure safe 
             * and effective ventilation.
             */
        subject airway :> advancedAirwaySystem;
    }
    
    requirement <'REQ-AA-006'> safetyRequirements {
        doc /* The advanced airway system shall operate within safe 
             * pressure limits and provide alarm capabilities for 
             * critical conditions to prevent patient harm.
             */
        subject airway :> advancedAirwaySystem;
        
        assert constraint pressureLimit {
            airway.pressureSensor.currentPressure <= airway.pressureSensor.maxPressure
        }
        
        assert constraint alarmEnabled {
            airway.controlUnit.alarmEnabled == true
        }
        
        assert constraint tidalVolumeRange {
            airway.controlUnit.targetTidalVolume >= 400 and
            airway.controlUnit.targetTidalVolume <= 600
        }
    }
    
    requirement <'REQ-AA-007'> deviceCompatibility {
        doc /* The advanced airway system shall maintain compatibility 
             * with standard ventilation equipment and monitoring systems.
             */
        subject airway :> advancedAirwaySystem;
        
        assert constraint standardConnector {
            airway.ventilationConnector.connectorType == "15mm ISO standard"
        }
    }
    
    satisfy primaryFunction by advancedAirwaySystem;
    satisfy secureAirwayPath by advancedAirwaySystem;
    satisfy preventAspiration by advancedAirwaySystem.cuffSystem;
    satisfy maintainOxygenation by advancedAirwaySystem.oxygenSensor;
    satisfy monitorVentilationParameters by advancedAirwaySystem;
    satisfy safetyRequirements by advancedAirwaySystem;
    satisfy deviceCompatibility by advancedAirwaySystem;
}
