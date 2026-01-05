package HypoglossalNerveStimulationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def DurationValue :> Real;
    attribute def ResistanceValue :> Real;
    attribute def OxygenSaturationValue :> Real;
    attribute def AirflowRateValue :> Real;
    
    item def StimulusParameters {
        attribute amplitude : CurrentValue;
        attribute frequency : FrequencyValue;
        attribute pulseWidth : DurationValue;
    }
    
    item def RespiratoryData {
        attribute breathingRate : FrequencyValue;
        attribute airflow : AirflowRateValue;
        attribute oxygenSaturation : OxygenSaturationValue;
        attribute apneaDetected : Boolean;
    }
    
    item def NeuralActivation {
        attribute activationLevel : Real;
        attribute responseLatency : DurationValue;
    }
    
    item def PatientCommand {
        attribute systemEnabled : Boolean;
        attribute intensityLevel : Real;
    }
    
    port def SensorPort {
        out respiratorySignal : RespiratoryData;
    }
    
    port def StimulationPort {
        in stimulusCommand : StimulusParameters;
    }
    
    port def ControlPort {
        in patientInput : PatientCommand;
    }
    
    port def NervePort {
        out neuralSignal : NeuralActivation;
    }
    
    part def RespiratorySensor {
        port sensorOutput : SensorPort;
        
        attribute samplingRate : FrequencyValue;
        attribute sensitivity : Real;
        
        action monitorRespiration {
            out respiratoryData : RespiratoryData;
        }
    }
    
    part def ImplantablePulseGenerator {
        port controlInput : ~ControlPort;
        port sensorInput : ~SensorPort;
        port stimulationOutput : StimulationPort;
        
        attribute batteryCapacity : Real;
        attribute currentBatteryLevel : Real;
        attribute deviceIdentifier : String;
        attribute therapyActive : Boolean;
        attribute baselineAmplitude : CurrentValue;
        attribute baselineFrequency : FrequencyValue;
        attribute basePulseWidth : DurationValue;
        attribute maxOutputCurrent : CurrentValue;
        attribute outputImpedance : ResistanceValue;
        
        action evaluateRespiratoryStatus {
            in respiratoryInput : RespiratoryData;
            out apneaEventDetected : Boolean;
            out eventSeverity : Real;
        }
        
        action computeStimulusParameters {
            in apneaDetected : Boolean;
            in severity : Real;
            in patientSettings : PatientCommand;
            out stimulusParams : StimulusParameters;
        }
        
        action generateStimulationPulse {
            in parameters : StimulusParameters;
            out pulseSignal : StimulusParameters;
        }
    }
    
    part def StimulationLead {
        port ipgConnection : ~StimulationPort;
        port electrodeConnection : StimulationPort;
        
        attribute leadLength : Real;
        attribute leadImpedance : ResistanceValue;
        attribute insulationIntegrity : Real;
        
        action conductStimulus {
            in inputSignal : StimulusParameters;
            out outputSignal : StimulusParameters;
        }
    }
    
    part def NerveCuffElectrode {
        port leadConnection : ~StimulationPort;
        port nerveInterface : NervePort;
        
        attribute contactArea : Real;
        attribute electrodeImpedance : ResistanceValue;
        attribute positionStability : Real;
        
        action deliverElectricalStimulation {
            in stimulus : StimulusParameters;
            out neuralResponse : NeuralActivation;
        }
    }
    
    part def HypoglossalNerve {
        port stimulationInterface : ~NervePort;
        
        attribute nerveDiameter : Real;
        attribute conductionVelocity : Real;
        attribute fiberDensity : Real;
        
        action propagateNeuralSignal {
            in activation : NeuralActivation;
            out motorCommand : NeuralActivation;
        }
    }
    
    part def GenioglossalMuscle {
        attribute muscleTonus : Real;
        attribute contractionStrength : Real;
        attribute fatigueLevel : Real;
        
        action contractMuscle {
            in neuralInput : NeuralActivation;
            out tongueDisplacement : Real;
            out muscleForce : Real;
        }
    }
    
    part def UpperAirway {
        attribute airwayDiameter : Real;
        attribute collapsibility : Real;
        attribute patencyStatus : Boolean;
        
        action maintainPatency {
            in tonguePosition : Real;
            in muscleForce : Real;
            out airwayOpening : Real;
            out airflowResistance : ResistanceValue;
        }
    }
    
    part def PatientController {
        port commandOutput : ControlPort;
        
        attribute userPreferences : Real;
        
        action issueCommand {
            out command : PatientCommand;
        }
    }
    
    part def Patient {
        part respiratorySystem {
            part sensor : RespiratorySensor;
            part airway : UpperAirway;
        }
        
        part anatomy {
            part tongue {
                part genioglossus : GenioglossalMuscle;
            }
            part cranialNerves {
                part hypoglossalNerve : HypoglossalNerve;
            }
        }
    }
    
    part hnsSystem : HypoglossalNerveStimulationSystem {
        doc /* 
        The Hypoglossal Nerve Stimulation System is an implantable medical device designed 
        to treat obstructive sleep apnea by delivering controlled electrical stimulation to 
        the hypoglossal nerve. The system continuously monitors the patient's respiratory 
        patterns during sleep. When an obstructive apnea event is detected, the system 
        activates the hypoglossal nerve, causing the genioglossal muscle to contract and 
        move the tongue forward, thereby opening the upper airway and restoring normal 
        breathing. This closed-loop therapy maintains airway patency throughout the night, 
        reducing apnea events and improving sleep quality and oxygenation.
        */
        
        part patientRemote : PatientController;
        part implantedDevice : ImplantablePulseGenerator;
        part stimulationLead : StimulationLead;
        part electrode : NerveCuffElectrode;
        part patient : Patient;
        
        connect patientRemote.commandOutput to implantedDevice.controlInput;
        connect patient.respiratorySystem.sensor.sensorOutput to implantedDevice.sensorInput;
        connect implantedDevice.stimulationOutput to stimulationLead.ipgConnection;
        connect stimulationLead.electrodeConnection to electrode.leadConnection;
        connect electrode.nerveInterface to patient.anatomy.cranialNerves.hypoglossalNerve.stimulationInterface;
        
        perform action therapeuticOperation[*] ordered;
    }
    
    action def DetectApnea {
        in respiratoryInput : RespiratoryData;
        out apneaIdentified : Boolean;
        out severityScore : Real;
    }
    
    action def GenerateTherapy {
        in apneaPresent : Boolean;
        in severity : Real;
        out stimulationNeeded : Boolean;
        out therapyParameters : StimulusParameters;
    }
    
    action def StimulateNerve {
        in therapy : StimulusParameters;
        out nerveActivated : NeuralActivation;
    }
    
    action def ContractTongue {
        in neuralCommand : NeuralActivation;
        out tongueMovement : Real;
    }
    
    action def RestoreAirway {
        in tonguePosition : Real;
        out airwayRestored : Boolean;
        out airflowImproved : AirflowRateValue;
    }
    
    action def TherapeuticOperation {
        first start;
        
        then action detectApneaEvent : DetectApnea {
            in respiratoryInput;
            out apneaIdentified;
            out severityScore;
        }
        
        then decide;
            if detectApneaEvent.apneaIdentified then initiateTherapy;
            if not detectApneaEvent.apneaIdentified then continueMonitoring;
        
        action initiateTherapy : GenerateTherapy {
            in apneaPresent = detectApneaEvent.apneaIdentified;
            in severity = detectApneaEvent.severityScore;
            out stimulationNeeded;
            out therapyParameters;
        }
        
        then action stimulateHypoglossalNerve : StimulateNerve {
            in therapy = initiateTherapy.therapyParameters;
            out nerveActivated;
        }
        
        then action activateTongueMuscle : ContractTongue {
            in neuralCommand = stimulateHypoglossalNerve.nerveActivated;
            out tongueMovement;
        }
        
        then action openUpperAirway : RestoreAirway {
            in tonguePosition = activateTongueMuscle.tongueMovement;
            out airwayRestored;
            out airflowImproved;
        }
        
        then merge continueMonitoring;
        
        action continueMonitoring;
        
        then start;
    }
    
    requirement def TherapeuticEfficacy {
        doc /* 
        The system shall effectively reduce obstructive sleep apnea events by maintaining 
        upper airway patency through targeted hypoglossal nerve stimulation.
        */
        
        require constraint apneaReductionTarget {
            doc /* The Apnea-Hypopnea Index (AHI) shall be reduced by at least 50% from baseline. */
        }
        
        require constraint oxygenMaintenance {
            doc /* Oxygen saturation shall be maintained above 90% during therapy. */
        }
        
        require constraint responseTime {
            doc /* Stimulation shall be delivered within 1 second of apnea detection. */
        }
    }
    
    requirement def SafetyRequirements {
        doc /* 
        The system shall operate within safe electrical parameters to prevent tissue damage 
        and ensure patient safety.
        */
        
        require constraint maximumCurrent {
            doc /* Stimulation current shall not exceed 5.0 mA. */
        }
        
        require constraint pulseWidthRange {
            doc /* Pulse width shall be between 50 and 500 microseconds. */
        }
        
        require constraint frequencyRange {
            doc /* Stimulation frequency shall be between 20 and 40 Hz. */
        }
        
        require constraint chargeBalancing {
            doc /* Each stimulation pulse shall be charge-balanced to prevent electrochemical tissue damage. */
        }
    }
    
    requirement def DeviceReliability {
        doc /* 
        The implantable device shall maintain reliable operation throughout its intended 
        service life under physiological conditions.
        */
        
        require constraint batteryLongevity {
            doc /* Battery shall provide at least 11 years of operation under typical use. */
        }
        
        require constraint electrodeStability {
            doc /* Electrode impedance shall remain within 20% of initial value over device lifetime. */
        }
        
        require constraint hermiticity {
            doc /* Device enclosure shall maintain hermetic seal preventing moisture ingress. */
        }
    }
    
    requirement def SystemPerformance {
        doc /* 
        The system shall deliver consistent therapeutic performance across varying patient 
        conditions and sleep stages.
        */
        
        require constraint detectionAccuracy {
            doc /* Apnea detection sensitivity shall be at least 95% with specificity above 90%. */
        }
        
        require constraint adaptiveTherapy {
            doc /* Stimulation parameters shall adapt to individual patient response within 5 therapy cycles. */
        }
        
        require constraint continuousOperation {
            doc /* System shall operate continuously for at least 8 hours per night. */
        }
    }
    
    requirement systemRequirements {
        subject system : hnsSystem;
        
        require efficacy : TherapeuticEfficacy;
        require safety : SafetyRequirements;
        require reliability : DeviceReliability;
        require performance : SystemPerformance;
        
        assume constraint properImplantation {
            doc /* Electrode is correctly positioned on the hypoglossal nerve with adequate contact. */
        }
        
        assume constraint patientCompliance {
            doc /* Patient activates the system nightly and maintains regular follow-up care. */
        }
        
        assume constraint anatomicalSuitability {
            doc /* Patient anatomy allows for effective tongue protrusion and airway opening. */
        }
    }
}
