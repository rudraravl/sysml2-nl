package InfraredThermometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def VoltageValue :> ISQ::VoltageValue;
    attribute def DistanceValue :> ISQ::LengthValue;
    attribute def EmissivityValue :> Real;
    attribute def TimeValue :> ISQ::DurationValue;
    attribute def AreaValue :> ISQ::AreaValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def AngleValue :> ISQ::PlaneAngleValue;
    attribute def ElectricCurrentValue :> ISQ::ElectricCurrentValue;
    
    enum def OperatingMode {
        off;
        standby;
        measuring;
        displaying;
        lowPower;
    }
    
    enum def MeasurementType {
        singlePoint;
        continuous;
        maxHold;
        minHold;
        average;
    }
    
    item def InfraredRadiation {
        attribute wavelength : DistanceValue;
        attribute intensity : Real;
        attribute emissivity : EmissivityValue;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute timestamp : TimeValue;
    }
    
    item def TemperatureData {
        attribute value : TemperatureValue;
        attribute emissivity : EmissivityValue;
        attribute distance : DistanceValue;
        attribute timestamp : TimeValue;
    }
    
    port def IRInputPort {
        in item radiation : InfraredRadiation;
    }
    
    port def SignalPort {
        out signal : ElectricalSignal;
    }
    
    port def DataPort {
        in data : TemperatureData;
    }
    
    port def ControlPort {
        in trigger : Boolean;
        in modeSelect : MeasurementType;
    }
    
    port def DisplayPort {
        out displayData : TemperatureData;
        out status : String;
    }
    
    part def OpticalLens {
        attribute apertureDiameter : DistanceValue;
        attribute focalLength : DistanceValue;
        attribute transmittance : Real;
        
        port irIn : IRInputPort;
        port irOut {
            out item focusedRadiation : InfraredRadiation;
        }
        
        action def FocusInfraredRadiation {
            in item incoming : InfraredRadiation;
            out item focused : InfraredRadiation;
        }
    }
    
    part def ThermopileSensor {
        attribute sensitivity : Real;
        attribute responseTime : TimeValue;
        attribute detectorArea : AreaValue;
        attribute operatingTemperature : TemperatureValue;
        
        port irInput {
            in item radiation : InfraredRadiation;
        }
        port signalOutput : SignalPort;
        
        action def ConvertRadiationToVoltage {
            in item radiation : InfraredRadiation;
            in ambientTemp : TemperatureValue;
            out signal : ElectricalSignal;
        }
    }
    
    part def SignalAmplifier {
        attribute gain : Real;
        attribute bandwidth : FrequencyValue;
        attribute noiseLevel : VoltageValue;
        
        port analogIn {
            in signal : ElectricalSignal;
        }
        port analogOut {
            out amplifiedSignal : ElectricalSignal;
        }
        
        action def AmplifySignal {
            in inputSignal : ElectricalSignal;
            out outputSignal : ElectricalSignal;
        }
    }
    
    part def AnalogToDigitalConverter {
        attribute resolution : Integer;
        attribute samplingRate : FrequencyValue;
        attribute referenceVoltage : VoltageValue;
        
        port analogInput {
            in signal : ElectricalSignal;
        }
        port digitalOutput {
            out digitalValue : Real;
        }
        
        action def ConvertSignal {
            in analog : ElectricalSignal;
            out digital : Real;
        }
    }
    
    part def Microcontroller {
        attribute clockSpeed : FrequencyValue;
        attribute memorySize : Real;
        attribute currentMode : OperatingMode;
        attribute measurementType : MeasurementType;
        attribute emissivitySetting : EmissivityValue;
        attribute maxRecordedTemp : TemperatureValue;
        attribute minRecordedTemp : TemperatureValue;
        
        port digitalIn {
            in digitalValue : Real;
        }
        port controlInput : ControlPort;
        port dataOutput {
            out tempData : TemperatureData;
        }
        port laserControl {
            out laserEnable : Boolean;
        }
        port batteryMonitor {
            in batteryLevel : Real;
        }
        
        action def CalculateTemperature {
            in digitalValue : Real;
            in emissivity : EmissivityValue;
            in ambientTemp : TemperatureValue;
            out temperature : TemperatureValue;
        }
        
        action def ProcessMeasurement {
            in rawValue : Real;
            in measurementMode : MeasurementType;
            out processedData : TemperatureData;
        }
        
        state def ControlStateMachine {
            entry; then powerOff;
            
            state powerOff;
            
            transition powerOff_to_standby
                first powerOff
                accept at powerOff.done
                then standby;
            
            state standby;
            
            transition standby_to_measuring
                first standby
                accept at standby.done
                then measuring;
            
            state measuring;
            
            transition measuring_to_displaying
                first measuring
                accept at measuring.done
                then displaying;
            
            state displaying;
            
            transition displaying_to_standby
                first displaying
                accept at displaying.done
                then standby;
            
            transition any_to_lowPower
                accept at powerOff.done
                then lowPower;
            
            state lowPower;
            
            transition lowPower_to_powerOff
                first lowPower
                accept at lowPower.done
                then powerOff;
        }
    }
    
    part def LCDDisplay {
        attribute screenSize : DistanceValue;
        attribute resolution : Integer[2];
        attribute backlightBrightness : Real;
        
        port displayInput : DataPort;
        
        action def RenderTemperature {
            in data : TemperatureData;
            in statusMessage : String;
        }
    }
    
    part def LaserPointer {
        attribute wavelength : DistanceValue;
        attribute outputPower : PowerValue;
        attribute beamDivergence : AngleValue;
        
        port control {
            in enable : Boolean;
        }
        
        action def ActivateLaser {
            in enable : Boolean;
        }
    }
    
    part def TriggerButton {
        attribute debounceTime : TimeValue;
        
        port buttonOutput {
            out pressed : Boolean;
        }
        
        state def ButtonStateMachine {
            entry; then released;
            
            state released;
            
            transition released_to_pressed
                first released
                accept at released.done
                then pressed;
            
            state pressed;
            
            transition pressed_to_released
                first pressed
                accept at pressed.done
                then released;
        }
    }
    
    part def ModeSelector {
        port modeOutput {
            out selectedMode : MeasurementType;
        }
        
        action def SelectMode {
            out mode : MeasurementType;
        }
    }
    
    part def PowerSupply {
        attribute batteryVoltage : VoltageValue;
        attribute batteryCapacity : Real;
        attribute currentCharge : Real;
        attribute outputVoltage : VoltageValue;
        
        port powerOutput {
            out voltage : VoltageValue;
            out current : ElectricCurrentValue;
        }
        port batteryStatus {
            out chargeLevel : Real;
        }
        
        assert constraint batteryConstraint {
            currentCharge >= 0.0 & currentCharge <= batteryCapacity
        }
    }
    
    part def AmbientTemperatureSensor {
        attribute accuracy : TemperatureValue;
        
        port tempOutput {
            out ambientTemp : TemperatureValue;
        }
        
        action def MeasureAmbient {
            out temperature : TemperatureValue;
        }
    }
    
    action def MeasureTargetTemperature {
        first start;
        then action activateLaser;
        then action captureRadiation : OpticalLens::FocusInfraredRadiation;
        then action detectRadiation : ThermopileSensor::ConvertRadiationToVoltage {
            in item radiation = captureRadiation.focused;
        }
        then action amplify : SignalAmplifier::AmplifySignal {
            in inputSignal = detectRadiation.signal;
        }
        then action digitize : AnalogToDigitalConverter::ConvertSignal {
            in analog = amplify.outputSignal;
        }
        then action calculate : Microcontroller::CalculateTemperature {
            in digitalValue = digitize.digital;
        }
        then action display : LCDDisplay::RenderTemperature;
        then action deactivateLaser;
        then done;
    }
    
    part def InfraredThermometer {
        attribute measurementRangeMin : TemperatureValue;
        attribute measurementRangeMax : TemperatureValue;
        attribute accuracy : TemperatureValue;
        attribute distanceToSpotRatio : Real;
        attribute currentTemperature : TemperatureValue;
        
        part optics : OpticalLens {
            attribute :>> apertureDiameter = 12.0;
            attribute :>> focalLength = 25.0;
            attribute :>> transmittance = 0.92;
        }
        
        part sensor : ThermopileSensor {
            attribute :>> sensitivity = 100.0;
            attribute :>> responseTime = 0.5;
            attribute :>> detectorArea = 1.0;
            attribute :>> operatingTemperature = 25.0;
        }
        
        part amplifier : SignalAmplifier {
            attribute :>> gain = 1000.0;
            attribute :>> bandwidth = 10.0;
            attribute :>> noiseLevel = 0.001;
        }
        
        part adc : AnalogToDigitalConverter {
            attribute :>> resolution = 16;
            attribute :>> samplingRate = 1000.0;
            attribute :>> referenceVoltage = 5.0;
        }
        
        part mcu : Microcontroller {
            attribute :>> clockSpeed = 48.0;
            attribute :>> memorySize = 256.0;
            attribute :>> emissivitySetting = 0.95;
            
            exhibit state controlBehavior : Microcontroller::ControlStateMachine;
        }
        
        part display : LCDDisplay {
            attribute :>> screenSize = 32.0;
            attribute :>> resolution = (128, 64);
            attribute :>> backlightBrightness = 80.0;
        }
        
        part laser : LaserPointer {
            attribute :>> wavelength = 650.0;
            attribute :>> outputPower = 1.0;
            attribute :>> beamDivergence = 0.5;
        }
        
        part trigger : TriggerButton {
            attribute :>> debounceTime = 0.05;
            
            exhibit state buttonBehavior : TriggerButton::ButtonStateMachine;
        }
        
        part modeSelector : ModeSelector;
        
        part battery : PowerSupply {
            attribute :>> batteryVoltage = 9.0;
            attribute :>> batteryCapacity = 2000.0;
            attribute :>> currentCharge = 2000.0;
            attribute :>> outputVoltage = 3.3;
        }
        
        part ambientSensor : AmbientTemperatureSensor {
            attribute :>> accuracy = 0.5;
        }
        
        connection opticsToSensor connect optics.irOut to sensor.irInput;
        connection sensorToAmplifier connect sensor.signalOutput to amplifier.analogIn;
        connection amplifierToADC connect amplifier.analogOut to adc.analogInput;
        connection adcToMCU connect adc.digitalOutput to mcu.digitalIn;
        connection mcuToDisplay connect mcu.dataOutput to display.displayInput;
        connection triggerToMCU connect trigger.buttonOutput to mcu.controlInput;
        connection modeSelectorToMCU connect modeSelector.modeOutput to mcu.controlInput;
        connection mcuToLaser connect mcu.laserControl to laser.control;
        connection batteryToMCU connect battery.batteryStatus to mcu.batteryMonitor;
        
        perform action measurementSequence : MeasureTargetTemperature;
    }
    
    requirement <'REQ-001'> primaryFunctionRequirement {
        doc /* The infrared thermometer shall measure the surface temperature 
             * of objects without physical contact by detecting and analyzing 
             * infrared radiation emitted from the target surface.
             */
        subject thermometer : InfraredThermometer;
    }
    
    requirement <'REQ-002'> measurementRangeRequirement {
        doc /* The thermometer shall measure temperatures in the range 
             * of -50 to +550 degrees Celsius.
             */
        subject thermometer : InfraredThermometer;
        
        assert constraint {
            thermometer.measurementRangeMin == -50.0 &
            thermometer.measurementRangeMax == 550.0
        }
    }
    
    requirement <'REQ-003'> accuracyRequirement {
        doc /* The thermometer shall provide temperature measurements 
             * with an accuracy of 1.5 degrees Celsius or 1.5 percent of the reading, 
             * whichever is greater.
             */
        subject thermometer : InfraredThermometer;
        
        assert constraint {
            thermometer.accuracy <= 1.5
        }
    }
    
    requirement <'REQ-004'> responseTimeRequirement {
        doc /* The thermometer shall provide a temperature reading 
             * within 500 milliseconds of trigger activation.
             */
        subject sensor : ThermopileSensor;
        
        assert constraint {
            sensor.responseTime <= 0.5
        }
    }
    
    requirement <'REQ-005'> distanceToSpotRequirement {
        doc /* The thermometer shall have a distance-to-spot ratio 
             * of at least 12:1 for accurate targeting.
             */
        subject thermometer : InfraredThermometer;
        
        assert constraint {
            thermometer.distanceToSpotRatio >= 12.0
        }
    }
    
    requirement <'REQ-006'> emissivityAdjustmentRequirement {
        doc /* The thermometer shall allow emissivity adjustment 
             * from 0.10 to 1.00 to accommodate different surface materials.
             */
        subject mcu : Microcontroller;
        
        assert constraint {
            mcu.emissivitySetting >= 0.10 &
            mcu.emissivitySetting <= 1.00
        }
    }
    
    requirement <'REQ-007'> laserTargetingRequirement {
        doc /* The thermometer shall include a laser pointer to visually 
             * indicate the measurement target area.
             */
        subject laser : LaserPointer;
        
        assert constraint {
            laser.wavelength == 650.0 &
            laser.outputPower <= 1.0
        }
    }
    
    requirement <'REQ-008'> displayRequirement {
        doc /* The thermometer shall display the measured temperature 
             * on an LCD screen with clear visibility.
             */
        subject display : LCDDisplay;
    }
    
    requirement <'REQ-009'> batteryLifeRequirement {
        doc /* The thermometer shall operate for at least 12 hours 
             * of continuous use on a single battery charge.
             */
        subject battery : PowerSupply;
    }
    
    requirement <'REQ-010'> measurementModesRequirement {
        doc /* The thermometer shall support multiple measurement modes 
             * including single point, continuous, max hold, min hold, 
             * and average.
             */
        subject mcu : Microcontroller;
    }
    
    part thermometerSystem : InfraredThermometer {
        attribute :>> measurementRangeMin = -50.0;
        attribute :>> measurementRangeMax = 550.0;
        attribute :>> accuracy = 1.5;
        attribute :>> distanceToSpotRatio = 12.0;
    }
    
    satisfy primaryFunctionRequirement by thermometerSystem;
    satisfy measurementRangeRequirement by thermometerSystem;
    satisfy accuracyRequirement by thermometerSystem;
    satisfy responseTimeRequirement by thermometerSystem.sensor;
    satisfy distanceToSpotRequirement by thermometerSystem;
    satisfy emissivityAdjustmentRequirement by thermometerSystem.mcu;
    satisfy laserTargetingRequirement by thermometerSystem.laser;
    satisfy displayRequirement by thermometerSystem.display;
    satisfy batteryLifeRequirement by thermometerSystem.battery;
    satisfy measurementModesRequirement by thermometerSystem.mcu;
}
