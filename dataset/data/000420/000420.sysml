package AlternatingElectricFieldTherapySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ElectricFieldStrength :> ISQ::ElectricFieldStrengthValue {
        doc /* Electric field strength measured in volts per centimeter */
    }
    
    attribute def TherapyFrequency :> ISQ::FrequencyValue {
        doc /* Frequency of alternating electric field in kilohertz */
    }
    
    attribute def SkinTemperature :> ISQ::ThermodynamicTemperatureValue {
        doc /* Temperature at transducer-skin interface */
    }
    
    attribute def TreatmentDuration :> ISQ::DurationValue {
        doc /* Duration of continuous treatment session */
    }
    
    attribute def TissueImpedance :> ISQ::ElectricResistanceValue {
        doc /* Electrical impedance of biological tissue */
    }
    
    attribute def FieldDirection :> Integer {
        doc /* Directional orientation of electric field vector */
    }
    
    item def TherapyParameters {
        attribute targetFrequency : TherapyFrequency;
        attribute targetFieldStrength : ElectricFieldStrength;
        attribute sessionDuration : TreatmentDuration;
        attribute directionSequence : FieldDirection[*];
    }
    
    item def ElectricFieldSignal {
        attribute frequency : TherapyFrequency;
        attribute fieldStrength : ElectricFieldStrength;
        attribute direction : FieldDirection;
    }
    
    item def SensorData {
        attribute temperature : SkinTemperature;
        attribute impedance : TissueImpedance;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def PowerSupply;
    item def ControlSignal;
    
    port def PowerInputPort {
        in item power : PowerSupply;
    }
    
    port def ControlPort {
        in item command : ControlSignal;
        out item status : Boolean;
    }
    
    port def FieldOutputPort {
        out item fieldSignal : ElectricFieldSignal;
    }
    
    port def SensorPort {
        out item sensorData : SensorData;
    }
    
    part def TransducerArray {
        doc /* Array of ceramic disk transducers that generate alternating electric fields when energized */
        
        attribute arrayIdentifier : String;
        attribute numberOfElements : Integer;
        attribute activeArea : ISQ::AreaValue;
        
        port fieldOutput : FieldOutputPort;
        port sensorOutput : SensorPort;
        
        perform action emitField {
            in signalInput : ElectricFieldSignal;
            out fieldOutput : ElectricFieldStrength;
        }
    }
    
    part def FieldGenerator {
        doc /* Electronic waveform generator that synthesizes alternating electric field signals */
        
        attribute operatingFrequency : TherapyFrequency;
        attribute outputAmplitude : ISQ::VoltageValue;
        
        port powerInput : PowerInputPort;
        port controlInput : ControlPort;
        port fieldOutputA : FieldOutputPort;
        port fieldOutputB : FieldOutputPort;
        port fieldOutputC : FieldOutputPort;
        port fieldOutputD : FieldOutputPort;
        
        perform action synthesizeWaveform {
            in frequency : TherapyFrequency;
            in amplitude : ISQ::VoltageValue;
            in direction : FieldDirection;
            out waveform : ElectricFieldSignal;
        }
    }
    
    part def ControlProcessor {
        doc /* Microprocessor-based control system managing therapy delivery and safety monitoring */
        
        attribute treatmentTimer : TreatmentDuration;
        attribute currentDirection : FieldDirection;
        attribute safetyEnabled : Boolean;
        
        port controlOutput : ControlPort;
        port sensorInputA : SensorPort;
        port sensorInputB : SensorPort;
        port sensorInputC : SensorPort;
        port sensorInputD : SensorPort;
        
        perform action manageTherapy;
        perform action monitorSafety;
        perform action rotateFieldDirection;
    }
    
    part def TemperatureSensor {
        doc /* Thermistor-based sensor monitoring transducer surface temperature */
        
        attribute currentTemperature : SkinTemperature;
        attribute alarmThreshold : SkinTemperature;
        
        port sensorOutput : SensorPort;
        
        perform action measureTemperature {
            out temperature : SkinTemperature;
        }
    }
    
    part def PowerModule {
        doc /* AC-DC power converter and battery backup system */
        
        attribute inputVoltage : ISQ::VoltageValue;
        attribute outputVoltage : ISQ::VoltageValue;
        attribute batteryCapacity : ISQ::EnergyValue;
        
        port acInput : PowerInputPort;
        port dcOutput : PowerInputPort;
        
        perform action convertPower {
            in acPower : ISQ::PowerValue;
            out dcPower : ISQ::PowerValue;
        }
    }
    
    part def BiologicalTarget {
        doc /* Tumor tissue target for therapeutic electric field application */
        
        attribute cellDivisionRate : Real;
        attribute tissueImpedance : TissueImpedance;
        attribute tumorVolume : ISQ::VolumeValue;
        
        port fieldReceptionA : FieldOutputPort;
        port fieldReceptionB : FieldOutputPort;
        port fieldReceptionC : FieldOutputPort;
        port fieldReceptionD : FieldOutputPort;
        
        perform action respondToField {
            in appliedField : ElectricFieldStrength;
            out cellularResponse : Real;
        }
    }
    
    action def InitializeSystem {
        in therapyConfig : TherapyParameters;
        out systemReady : Boolean;
        
        first start;
        then action performSelfTest {
            out testResult : Boolean;
        }
        then action loadConfiguration {
            in config : TherapyParameters;
            out configLoaded : Boolean;
        }
        then decide;
            if performSelfTest.testResult and loadConfiguration.configLoaded then success;
            if not performSelfTest.testResult or not loadConfiguration.configLoaded then failure;
        action success {
            then assign systemReady := true;
        }
        then done;
        action failure {
            then assign systemReady := false;
        }
        then done;
    }
    
    action def DeliverAlternatingField {
        in fieldStrength : ElectricFieldStrength;
        in frequency : TherapyFrequency;
        in direction : FieldDirection;
        in duration : TreatmentDuration;
        out therapeuticEffect : Real;
        
        first start;
        then action activateGenerator {
            in freq : TherapyFrequency = frequency;
            in strength : ElectricFieldStrength = fieldStrength;
            in dir : FieldDirection = direction;
            out generatorActive : Boolean;
        }
        then action applyFieldToTarget {
            in activeField : ElectricFieldStrength = fieldStrength;
            out cellularDisruption : Real;
        }
        then assign therapeuticEffect := applyFieldToTarget.cellularDisruption;
        then done;
    }
    
    action def RotateFieldOrientation {
        in currentDirection : FieldDirection;
        in rotationInterval : TreatmentDuration;
        out newDirection : FieldDirection;
        
        first start;
        then decide;
            if currentDirection == 1 then setDirection2;
            if currentDirection == 2 then setDirection1;
        action setDirection2 {
            then assign newDirection := 2;
        }
        then done;
        action setDirection1 {
            then assign newDirection := 1;
        }
        then done;
    }
    
    action def MonitorSafetyParameters {
        in temperature : SkinTemperature;
        in impedance : TissueImpedance;
        in maxTemperature : SkinTemperature;
        in maxImpedance : TissueImpedance;
        out safetyStatus : Boolean;
        
        first start;
        then decide;
            if temperature <= maxTemperature and impedance <= maxImpedance then safe;
            if temperature > maxTemperature or impedance > maxImpedance then unsafe;
        action safe {
            then assign safetyStatus := true;
        }
        then done;
        action unsafe {
            then assign safetyStatus := false;
        }
        then done;
    }
    
    action def TerminateTherapy {
        in completionStatus : Boolean;
        out shutdownComplete : Boolean;
        
        first start;
        then action deactivateGenerator {
            out generatorOff : Boolean;
        }
        then action recordSession {
            in status : Boolean = completionStatus;
            out sessionRecorded : Boolean;
        }
        then assign shutdownComplete := true;
        then done;
    }
    
    part def TherapyDevice;
    
    part alternatingFieldTherapySystem : TherapyDevice {
        doc /* Complete alternating electric field therapy system for disrupting cancer cell mitosis through low-intensity, intermediate-frequency electric fields */
        
        attribute systemFrequency : TherapyFrequency;
        attribute systemFieldStrength : ElectricFieldStrength;
        attribute totalTreatmentTime : TreatmentDuration;
        
        part powerModule : PowerModule {
            attribute inputVoltage = 120.0 [SI::V];
            attribute outputVoltage = 24.0 [SI::V];
            attribute batteryCapacity = 100.0 [SI::W * SI::h];
        }
        
        part controlProcessor : ControlProcessor {
            attribute treatmentTimer = 18.0 [SI::h];
            attribute currentDirection = 1;
            attribute safetyEnabled = true;
        }
        
        part fieldGenerator : FieldGenerator {
            attribute operatingFrequency = 200000.0 [SI::Hz];
            attribute outputAmplitude = 150.0 [SI::V];
        }
        
        part transducerArrayAnterior : TransducerArray {
            attribute arrayIdentifier = "Anterior";
            attribute numberOfElements = 9;
            attribute activeArea = 0.01 [SI::m ** 2];
        }
        
        part transducerArrayPosterior : TransducerArray {
            attribute arrayIdentifier = "Posterior";
            attribute numberOfElements = 9;
            attribute activeArea = 0.01 [SI::m ** 2];
        }
        
        part transducerArrayLeft : TransducerArray {
            attribute arrayIdentifier = "Left";
            attribute numberOfElements = 9;
            attribute activeArea = 0.01 [SI::m ** 2];
        }
        
        part transducerArrayRight : TransducerArray {
            attribute arrayIdentifier = "Right";
            attribute numberOfElements = 9;
            attribute activeArea = 0.01 [SI::m ** 2];
        }
        
        part temperatureSensorAnterior : TemperatureSensor {
            attribute alarmThreshold = 314.0 [SI::K];
        }
        
        part temperatureSensorPosterior : TemperatureSensor {
            attribute alarmThreshold = 314.0 [SI::K];
        }
        
        part temperatureSensorLeft : TemperatureSensor {
            attribute alarmThreshold = 314.0 [SI::K];
        }
        
        part temperatureSensorRight : TemperatureSensor {
            attribute alarmThreshold = 314.0 [SI::K];
        }
        
        part biologicalTarget : BiologicalTarget {
            attribute cellDivisionRate = 0.25;
            attribute tissueImpedance = 1200.0 [SI::Ω];
            attribute tumorVolume = 0.00005 [SI::m ** 3];
        }
        
        connect powerModule.dcOutput to fieldGenerator.powerInput;
        connect controlProcessor.controlOutput to fieldGenerator.controlInput;
        connect fieldGenerator.fieldOutputA to transducerArrayAnterior.fieldOutput;
        connect fieldGenerator.fieldOutputB to transducerArrayPosterior.fieldOutput;
        connect fieldGenerator.fieldOutputC to transducerArrayLeft.fieldOutput;
        connect fieldGenerator.fieldOutputD to transducerArrayRight.fieldOutput;
        connect temperatureSensorAnterior.sensorOutput to controlProcessor.sensorInputA;
        connect temperatureSensorPosterior.sensorOutput to controlProcessor.sensorInputB;
        connect temperatureSensorLeft.sensorOutput to controlProcessor.sensorInputC;
        connect temperatureSensorRight.sensorOutput to controlProcessor.sensorInputD;
        connect transducerArrayAnterior.fieldOutput to biologicalTarget.fieldReceptionA;
        connect transducerArrayPosterior.fieldOutput to biologicalTarget.fieldReceptionB;
        connect transducerArrayLeft.fieldOutput to biologicalTarget.fieldReceptionC;
        connect transducerArrayRight.fieldOutput to biologicalTarget.fieldReceptionD;
        
        perform action executeTherapy : TherapyDeliverySequence;
    }
    
    action def TherapyDeliverySequence {
        doc /* Primary therapeutic action sequence: deliver alternating electric fields to disrupt mitotic spindle formation in dividing cancer cells */
        
        first start;
        
        then action initialize : InitializeSystem {
            in therapyConfig : TherapyParameters {
                attribute targetFrequency = 200000.0 [SI::Hz];
                attribute targetFieldStrength = 150.0 [SI::V] / 1.0 [SI::m];
                attribute sessionDuration = 64800.0 [SI::s];
            }
            out systemReady : Boolean;
        }
        
        then decide;
            if initialize.systemReady then beginTreatment;
            if not initialize.systemReady then abortTherapy;
        
        action beginTreatment {
            first merge continueTreatment;
            
            private attribute elapsedTime : TreatmentDuration := 0.0 [SI::s];
            private attribute currentDir : FieldDirection := 1;
            private attribute rotationInterval : TreatmentDuration := 1.0 [SI::s];
            
            then action deliverField : DeliverAlternatingField {
                in fieldStrength = 150.0 [SI::V] / 1.0 [SI::m];
                in frequency = 200000.0 [SI::Hz];
                in direction = currentDir;
                in duration = rotationInterval;
                out therapeuticEffect : Real;
            }
            
            then action rotateField : RotateFieldOrientation {
                in currentDirection = currentDir;
                in rotationInterval = rotationInterval;
                out newDirection : FieldDirection;
            }
            
            then assign currentDir := rotateField.newDirection;
            
            then action checkSafety : MonitorSafetyParameters {
                in temperature : SkinTemperature;
                in impedance : TissueImpedance;
                in maxTemperature = 314.0 [SI::K];
                in maxImpedance = 2000.0 [SI::Ω];
                out safetyStatus : Boolean;
            }
            
            then assign elapsedTime := elapsedTime + rotationInterval;
            
            then decide;
                if checkSafety.safetyStatus and elapsedTime < 64800.0 [SI::s] then continueTreatment;
                if not checkSafety.safetyStatus then emergencyStop;
                if elapsedTime >= 64800.0 [SI::s] then completeTherapy;
        }
        
        action completeTherapy : TerminateTherapy {
            in completionStatus = true;
            out shutdownComplete : Boolean;
        }
        then done;
        
        action emergencyStop : TerminateTherapy {
            in completionStatus = false;
            out shutdownComplete : Boolean;
        }
        then done;
        
        action abortTherapy : TerminateTherapy {
            in completionStatus = false;
            out shutdownComplete : Boolean;
        }
        then done;
    }
    
    state def TherapySystemLifecycle {
        entry; then idle;
        
        state idle {
            doc /* System powered but not delivering therapy */
        }
        transition idle to initializing when InitializeSystem;
        
        state initializing {
            doc /* System performing self-test and configuration */
        }
        transition initializing to ready when InitializeSystem;
        transition initializing to fault when TerminateTherapy;
        
        state ready {
            doc /* System ready to begin therapy delivery */
        }
        transition ready to delivering when ControlSignal;
        
        state delivering {
            doc /* System actively delivering alternating electric fields */
            entry action deliverField : DeliverAlternatingField;
        }
        transition delivering to delivering when RotateFieldOrientation;
        transition delivering to completed when TerminateTherapy;
        transition delivering to fault when MonitorSafetyParameters;
        
        state completed {
            doc /* Treatment session successfully completed */
        }
        transition completed to idle when TerminateTherapy;
        
        state fault {
            doc /* System in fault state due to safety violation or initialization failure */
        }
        transition fault to idle when TerminateTherapy;
    }
    
    requirement def TherapyEffectivenessRequirement {
        doc /* The system shall deliver electric fields of sufficient strength to disrupt mitotic spindle formation */
        
        subject system : TherapyDevice;
        
        require constraint {
            system.systemFieldStrength >= 100.0 [SI::V] / 1.0 [SI::m] and
            system.systemFieldStrength <= 300.0 [SI::V] / 1.0 [SI::m]
        }
    }
    
    requirement def FrequencySpecificationRequirement {
        doc /* The system shall operate at tumor-specific intermediate frequencies */
        
        subject system : TherapyDevice;
        
        require constraint {
            system.systemFrequency >= 100000.0 [SI::Hz] and
            system.systemFrequency <= 300000.0 [SI::Hz]
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall maintain safe operating temperatures at all transducer-skin interfaces */
        
        subject sensor : TemperatureSensor;
        
        require constraint {
            sensor.currentTemperature < sensor.alarmThreshold
        }
    }
    
    requirement def TreatmentDurationRequirement {
        doc /* The system shall support continuous treatment for minimum recommended daily duration */
        
        subject system : TherapyDevice;
        
        require constraint {
            system.totalTreatmentTime >= 64800.0 [SI::s]
        }
    }
    
    requirement def FieldDirectionRequirement {
        doc /* The system shall alternate field direction to maximize therapeutic coverage */
        
        subject generator : FieldGenerator;
        
        require constraint {
            true
        }
    }
    
    requirement <'TTF-REQ-001'> primaryTherapyRequirement {
        doc /* The alternating electric field therapy system shall disrupt mitotic spindle formation in dividing cancer cells by applying low-intensity, intermediate-frequency alternating electric fields in orthogonal directions, thereby interfering with proper chromosome segregation during cell division and inducing mitotic catastrophe in tumor cells while sparing non-dividing healthy tissue. */
        
        subject therapySystem : TherapyDevice;
        
        assume constraint tumorPresent {
            doc /* Actively dividing tumor cells are present within the treatment field volume */
            therapySystem.biologicalTarget.cellDivisionRate > 0.0
        }
        
        assume constraint properArrayPlacement {
            doc /* Transducer arrays are properly positioned to deliver orthogonal electric fields through tumor volume */
            therapySystem.transducerArrayAnterior.activeArea > 0.0 [SI::m ** 2] and
            therapySystem.transducerArrayPosterior.activeArea > 0.0 [SI::m ** 2]
        }
        
        require effectivenessReq : TherapyEffectivenessRequirement;
        require frequencyReq : FrequencySpecificationRequirement;
        require safetyReq : SafetyRequirement;
        require durationReq : TreatmentDurationRequirement;
        require directionReq : FieldDirectionRequirement;
    }
}
