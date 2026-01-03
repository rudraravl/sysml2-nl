package 'Puritan Bennett Ventilator System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VentilationMode;
    attribute def AlarmCondition;
    attribute def PatientTrigger;
    
    port def GasSupplyPort {
        out flow : ISQ::VolumeFlowRateValue;
        out pressure : ISQ::PressureValue;
    }
    
    port def PatientInterfacePort {
        out deliveryPressure : ISQ::PressureValue;
        out deliveryFlow : ISQ::VolumeFlowRateValue;
        in returnPressure : ISQ::PressureValue;
        in returnFlow : ISQ::VolumeFlowRateValue;
    }
    
    port def SensorPort {
        in measuredValue : Real;
        out sensorReading : Real;
    }
    
    port def ControlPort {
        in setpoint : Real;
        out command : Real;
    }
    
    attribute def RespiratoryRateValue {
        attribute breathsPerMinute : Real;
    }
    
    attribute def OxygenConcentrationValue {
        attribute percentage : Real;
    }
    
    part def AirCompressor {
        port airOut : GasSupplyPort;
        attribute maxPressure : ISQ::PressureValue;
        attribute maxFlow : ISQ::VolumeFlowRateValue;
        
        action compressAir {
            in ambientPressure : ISQ::PressureValue;
            out compressedPressure : ISQ::PressureValue;
            out compressedFlow : ISQ::VolumeFlowRateValue;
        }
    }
    
    part def OxygenSource {
        port oxygenOut : GasSupplyPort;
        attribute concentration : OxygenConcentrationValue;
        attribute supplyPressure : ISQ::PressureValue;
        
        action supplyOxygen {
            in demandFlow : ISQ::VolumeFlowRateValue;
            out oxygenFlow : ISQ::VolumeFlowRateValue;
            out oxygenPressure : ISQ::PressureValue;
        }
    }
    
    part def GasMixer {
        port airIn : GasSupplyPort;
        port oxygenIn : GasSupplyPort;
        port mixedGasOut : GasSupplyPort;
        
        attribute targetFiO2 : OxygenConcentrationValue;
        attribute actualFiO2 : OxygenConcentrationValue;
        
        action mixGases {
            in airFlowIn : ISQ::VolumeFlowRateValue;
            in oxygenFlowIn : ISQ::VolumeFlowRateValue;
            in targetConcentration : OxygenConcentrationValue;
            out mixedFlow : ISQ::VolumeFlowRateValue;
            out actualConcentration : OxygenConcentrationValue;
        }
    }
    
    part def InspiratoryValve {
        port gasIn : GasSupplyPort;
        port gasOut : GasSupplyPort;
        
        attribute valvePosition : Real;
        attribute isOpen : Boolean;
        
        action controlValve {
            in commandSignal : Real;
            in inputFlow : ISQ::VolumeFlowRateValue;
            out outputFlow : ISQ::VolumeFlowRateValue;
            out position : Real;
        }
    }
    
    part def ExpiratoryValve {
        port gasIn : GasSupplyPort;
        port gasOut : GasSupplyPort;
        
        attribute valvePosition : Real;
        attribute peepLevel : ISQ::PressureValue;
        
        action maintainPEEP {
            in targetPEEP : ISQ::PressureValue;
            in measuredPressure : ISQ::PressureValue;
            out adjustedPosition : Real;
        }
    }
    
    part def PressureTransducer {
        port sensing : SensorPort;
        
        attribute calibrationFactor : Real;
        attribute accuracy : Real;
        
        action measurePressure {
            in physicalPressure : ISQ::PressureValue;
            out digitalReading : ISQ::PressureValue;
        }
    }
    
    part def FlowTransducer {
        port sensing : SensorPort;
        
        attribute calibrationFactor : Real;
        attribute responseTime : ISQ::TimeValue;
        
        action measureFlow {
            in physicalFlow : ISQ::VolumeFlowRateValue;
            out digitalReading : ISQ::VolumeFlowRateValue;
        }
    }
    
    part def VolumeMonitor {
        attribute accumulatedVolume : ISQ::VolumeValue;
        attribute tidalVolume : ISQ::VolumeValue;
        
        action integrateVolume {
            in flowRate : ISQ::VolumeFlowRateValue;
            in timeInterval : ISQ::TimeValue;
            out calculatedVolume : ISQ::VolumeValue;
        }
    }
    
    part def OxygenSensor {
        port sensing : SensorPort;
        
        attribute measuredFiO2 : OxygenConcentrationValue;
        
        action measureOxygen {
            in gasConcentration : OxygenConcentrationValue;
            out reading : OxygenConcentrationValue;
        }
    }
    
    part def AlarmModule {
        attribute highPressureLimit : ISQ::PressureValue;
        attribute lowPressureLimit : ISQ::PressureValue;
        attribute highVolumeLimit : ISQ::VolumeValue;
        attribute lowVolumeLimit : ISQ::VolumeValue;
        attribute apneaTimeout : ISQ::TimeValue;
        
        action evaluateAlarms {
            in currentPressure : ISQ::PressureValue;
            in currentVolume : ISQ::VolumeValue;
            in currentFlow : ISQ::VolumeFlowRateValue;
            in timeSinceLastBreath : ISQ::TimeValue;
            out alarmStatus : AlarmCondition;
        }
    }
    
    part def BreathController {
        port controlInterface : ControlPort;
        
        attribute ventilationMode : VentilationMode;
        attribute targetTidalVolume : ISQ::VolumeValue;
        attribute targetRespiratoryRate : RespiratoryRateValue;
        attribute targetPEEP : ISQ::PressureValue;
        attribute targetFiO2 : OxygenConcentrationValue;
        attribute inspiratoryTime : ISQ::TimeValue;
        attribute expiratoryTime : ISQ::TimeValue;
        attribute peakInspiratoryPressure : ISQ::PressureValue;
        
        action calculateBreathParameters {
            in mode : VentilationMode;
            in tidalVolume : ISQ::VolumeValue;
            in respiratoryRate : RespiratoryRateValue;
            out inspTime : ISQ::TimeValue;
            out expTime : ISQ::TimeValue;
            out targetFlow : ISQ::VolumeFlowRateValue;
        }
        
        action detectPatientEffort {
            in flowSignal : ISQ::VolumeFlowRateValue;
            in pressureSignal : ISQ::PressureValue;
            out triggerDetected : PatientTrigger;
        }
        
        action generateControlSignals {
            in breathPhase : Real;
            in measuredPressure : ISQ::PressureValue;
            in measuredFlow : ISQ::VolumeFlowRateValue;
            in measuredVolume : ISQ::VolumeValue;
            out inspiratoryValveCommand : Real;
            out expiratoryValveCommand : Real;
        }
    }
    
    part def PatientCircuit {
        port ventilatorConnection : PatientInterfacePort;
        port patientConnection : PatientInterfacePort;
        
        attribute circuitCompliance : Real;
        attribute circuitResistance : Real;
        
        action deliverBreath {
            in inspiratoryFlow : ISQ::VolumeFlowRateValue;
            in inspiratoryPressure : ISQ::PressureValue;
            out deliveredVolume : ISQ::VolumeValue;
            out airwayPressure : ISQ::PressureValue;
        }
        
        action allowExhalation {
            in peepPressure : ISQ::PressureValue;
            out exhalationFlow : ISQ::VolumeFlowRateValue;
            out exhaledVolume : ISQ::VolumeValue;
        }
    }
    
    part def UserInterface {
        attribute displayedParameters : Real[*];
        attribute alarmIndicators : AlarmCondition[*];
        
        action displayStatus {
            in currentPressure : ISQ::PressureValue;
            in currentVolume : ISQ::VolumeValue;
            in currentFlow : ISQ::VolumeFlowRateValue;
            in currentFiO2 : OxygenConcentrationValue;
            in alarms : AlarmCondition;
        }
        
        action acceptSettings {
            out mode : VentilationMode;
            out tidalVolume : ISQ::VolumeValue;
            out respiratoryRate : RespiratoryRateValue;
            out peep : ISQ::PressureValue;
            out fiO2 : OxygenConcentrationValue;
        }
    }
    
    part def PuritanBennettVentilator {
        doc /*
            The Puritan Bennett mechanical ventilator system provides life-sustaining
            respiratory support to patients who are unable to breathe adequately on their own.
            The system delivers controlled mechanical ventilation by precisely managing gas
            flow, pressure, and volume through automated respiratory cycles while continuously
            monitoring patient parameters and maintaining safety limits.
        */
        
        port airSupply : GasSupplyPort;
        port oxygenSupply : GasSupplyPort;
        port patientInterface : PatientInterfacePort;
        
        part compressor : AirCompressor {
            port :>> airOut = airSupply;
        }
        
        part oxygenSource : OxygenSource {
            port :>> oxygenOut = oxygenSupply;
        }
        
        part mixer : GasMixer;
        
        part inspiratoryValve : InspiratoryValve;
        part expiratoryValve : ExpiratoryValve;
        
        part pressureSensor : PressureTransducer;
        part flowSensor : FlowTransducer;
        part volumeMonitor : VolumeMonitor;
        part oxygenSensor : OxygenSensor;
        
        part controller : BreathController;
        part alarmSystem : AlarmModule;
        part userInterface : UserInterface;
        
        part circuit : PatientCircuit {
            port :>> ventilatorConnection = patientInterface;
        }
        
        connection airToMixer connect compressor.airOut to mixer.airIn;
        connection oxygenToMixer connect oxygenSource.oxygenOut to mixer.oxygenIn;
        connection mixerToInspValve connect mixer.mixedGasOut to inspiratoryValve.gasIn;
        connection inspValveToCircuit connect inspiratoryValve.gasOut to circuit.ventilatorConnection;
        connection circuitToExpValve connect circuit.ventilatorConnection to expiratoryValve.gasIn;
        
        perform action provideMechanicalVentilation {
            doc /*
                Primary function: Deliver controlled mechanical ventilation to support
                patient breathing by managing inspiratory and expiratory phases through
                precise control of gas flow, pressure, and volume while ensuring patient
                safety through continuous monitoring and alarm management.
            */
            
            first start;
            then merge ventilationLoop;
            
            then action initializeSystem {
                first action powerOn;
                then action selfTest {
                    out testResult : Boolean;
                }
                then action calibrateSensors {
                    first action calibratePressure;
                    then action calibrateFlow;
                    then action calibrateOxygen;
                }
                then action loadSettings {
                    in userMode : VentilationMode;
                    in userTidalVolume : ISQ::VolumeValue;
                    in userRate : RespiratoryRateValue;
                    in userPEEP : ISQ::PressureValue;
                    in userFiO2 : OxygenConcentrationValue;
                }
            }
            
            then action ventilationCycle {
                first action inspiratoryPhase {
                    first action detectTrigger {
                        in flowSignal : ISQ::VolumeFlowRateValue;
                        in pressureSignal : ISQ::PressureValue;
                        in timeElapsed : ISQ::TimeValue;
                        out triggerOccurred : Boolean;
                    }
                    
                    then action blendGas {
                        in targetOxygenConcentration : OxygenConcentrationValue;
                        in airFlowRate : ISQ::VolumeFlowRateValue;
                        in oxygenFlowRate : ISQ::VolumeFlowRateValue;
                        out mixedGasFlow : ISQ::VolumeFlowRateValue;
                        out actualFiO2 : OxygenConcentrationValue;
                    }
                    
                    then action openInspiratoryValve {
                        in flowCommand : ISQ::VolumeFlowRateValue;
                        out valvePosition : Real;
                    }
                    
                    then merge deliveryControl;
                    
                    then action monitorDelivery {
                        first action measureAirwayPressure {
                            in sensorInput : ISQ::PressureValue;
                            out pressureReading : ISQ::PressureValue;
                        }
                        then action measureInspiratoryFlow {
                            in sensorInput : ISQ::VolumeFlowRateValue;
                            out flowReading : ISQ::VolumeFlowRateValue;
                        }
                        then action calculateDeliveredVolume {
                            in flowData : ISQ::VolumeFlowRateValue;
                            in timeInterval : ISQ::TimeValue;
                            out volumeData : ISQ::VolumeValue;
                        }
                    }
                    
                    then action adjustDelivery {
                        in targetVolume : ISQ::VolumeValue;
                        in measuredVolume : ISQ::VolumeValue;
                        in targetPressure : ISQ::PressureValue;
                        in measuredPressure : ISQ::PressureValue;
                        out flowAdjustment : ISQ::VolumeFlowRateValue;
                    }
                    
                    then decide;
                        if adjustDelivery.measuredVolume < adjustDelivery.targetVolume 
                           and adjustDelivery.measuredPressure < adjustDelivery.targetPressure 
                        then deliveryControl;
                        
                        if adjustDelivery.measuredVolume >= adjustDelivery.targetVolume 
                           or adjustDelivery.measuredPressure >= adjustDelivery.targetPressure 
                        then endInspiration;
                    
                    action endInspiration {
                        first action closeInspiratoryValve;
                        then action recordPeakPressure {
                            in maxPressure : ISQ::PressureValue;
                            out peakInspPressure : ISQ::PressureValue;
                        }
                        then action recordTidalVolume {
                            in deliveredVolume : ISQ::VolumeValue;
                            out tidalVol : ISQ::VolumeValue;
                        }
                    }
                }
                
                then action expiratoryPhase {
                    first action openExpiratoryValve {
                        in peepSetpoint : ISQ::PressureValue;
                        out valvePosition : Real;
                    }
                    
                    then merge exhalationControl;
                    
                    then action monitorExhalation {
                        first action measureExpiratoryFlow {
                            in sensorInput : ISQ::VolumeFlowRateValue;
                            out flowReading : ISQ::VolumeFlowRateValue;
                        }
                        then action measureAirwayPressure {
                            in sensorInput : ISQ::PressureValue;
                            out pressureReading : ISQ::PressureValue;
                        }
                        then action calculateExhaledVolume {
                            in flowData : ISQ::VolumeFlowRateValue;
                            in timeInterval : ISQ::TimeValue;
                            out volumeData : ISQ::VolumeValue;
                        }
                    }
                    
                    then action maintainPEEP {
                        in targetPEEP : ISQ::PressureValue;
                        in measuredPressure : ISQ::PressureValue;
                        out valveAdjustment : Real;
                    }
                    
                    then decide;
                        if maintainPEEP.measuredPressure > maintainPEEP.targetPEEP 
                        then exhalationControl;
                        
                        if maintainPEEP.measuredPressure <= maintainPEEP.targetPEEP 
                        then endExpiration;
                    
                    action endExpiration {
                        action recordExhaledVolume {
                            in exhaledVol : ISQ::VolumeValue;
                            out recordedExhaledVol : ISQ::VolumeValue;
                        }
                    }
                }
                
                then action performSafetyChecks {
                    first action checkPressureLimits {
                        in peakPressure : ISQ::PressureValue;
                        in highLimit : ISQ::PressureValue;
                        in lowLimit : ISQ::PressureValue;
                        out pressureAlarm : AlarmCondition;
                    }
                    
                    then action checkVolumeLimits {
                        in tidalVolume : ISQ::VolumeValue;
                        in exhaledVolume : ISQ::VolumeValue;
                        in highLimit : ISQ::VolumeValue;
                        in lowLimit : ISQ::VolumeValue;
                        out volumeAlarm : AlarmCondition;
                    }
                    
                    then action checkApnea {
                        in timeSinceLastBreath : ISQ::TimeValue;
                        in apneaLimit : ISQ::TimeValue;
                        out apneaAlarm : AlarmCondition;
                    }
                    
                    then action checkOxygenConcentration {
                        in measuredFiO2 : OxygenConcentrationValue;
                        in targetFiO2 : OxygenConcentrationValue;
                        in tolerance : Real;
                        out oxygenAlarm : AlarmCondition;
                    }
                    
                    then decide;
                        if checkPressureLimits.pressureAlarm 
                           or checkVolumeLimits.volumeAlarm 
                           or checkApnea.apneaAlarm 
                           or checkOxygenConcentration.oxygenAlarm 
                        then activateAlarm;
                    
                    action activateAlarm {
                        in alarmType : AlarmCondition;
                        out alarmSignal : AlarmCondition;
                    }
                }
                
                then action updateDisplay {
                    in currentPressure : ISQ::PressureValue;
                    in currentVolume : ISQ::VolumeValue;
                    in currentFlow : ISQ::VolumeFlowRateValue;
                    in currentFiO2 : OxygenConcentrationValue;
                    in alarmStatus : AlarmCondition;
                }
                
                then action adaptParameters {
                    in breathData : Real[*];
                    in patientResponse : Real;
                    out updatedSettings : Real[*];
                }
            }
            
            then ventilationLoop;
        }
    }
    
    requirement <'VNT-REQ-001'> mechanicalVentilationRequirement {
        doc /*
            The Puritan Bennett ventilator system shall provide controlled mechanical
            ventilation to patients by delivering precise tidal volumes at specified
            respiratory rates while maintaining patient safety through continuous
            monitoring and alarm management.
        */
        
        subject ventilator : PuritanBennettVentilator;
        
        require constraint tidalVolumeAccuracy {
            doc /* Delivered tidal volume shall be within ±10% of set value or ±10 mL, whichever is greater. */
        }
        
        require constraint respiratoryRateAccuracy {
            doc /* Respiratory rate shall be maintained within ±1 breath per minute of set value. */
        }
        
        require constraint pressureLimits {
            doc /* Peak inspiratory pressure shall not exceed 120 cmH2O and shall trigger alarm at set limit. */
        }
        
        require constraint peepAccuracy {
            doc /* PEEP shall be maintained within ±2 cmH2O of set value. */
        }
    }
    
    requirement <'VNT-REQ-002'> oxygenDeliveryRequirement {
        doc /*
            The system shall deliver medical gas with precisely controlled oxygen
            concentration (FiO2) ranging from 21% to 100% with specified accuracy.
        */
        
        require constraint fiO2Range {
            doc /* FiO2 shall be adjustable from 21% to 100% in 1% increments. */
        }
        
        require constraint fiO2Accuracy {
            doc /* Delivered FiO2 shall be within ±3% of set value. */
        }
    }
    
    requirement <'VNT-REQ-003'> monitoringAndAlarmRequirement {
        doc /*
            The system shall continuously monitor respiratory parameters and activate
            alarms for out-of-range conditions within specified response times.
        */
        
        require constraint continuousMonitoring {
            doc /* Pressure, flow, and volume shall be monitored at minimum 100 Hz sampling rate. */
        }
        
        require constraint alarmResponseTime {
            doc /* High priority alarms shall activate within 5 seconds of condition detection. */
        }
        
        require constraint alarmConditions {
            doc /* System shall alarm for high/low pressure, high/low volume, apnea, and oxygen concentration deviation. */
        }
    }
    
    requirement <'VNT-REQ-004'> reliabilityRequirement {
        doc /*
            The ventilator shall operate with high reliability to ensure uninterrupted
            patient support during critical care situations.
        */
        
        require constraint systemUptime {
            doc /* System shall maintain 99.9% uptime during normal operation. */
        }
        
        require constraint backupSystems {
            doc /* System shall include backup battery power for minimum 30 minutes operation. */
        }
        
        require constraint failsafeModes {
            doc /* System shall enter safe ventilation mode upon component failure. */
        }
    }
}
