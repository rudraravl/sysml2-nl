package ViscometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ViscosityValue :> ISQ::DynamicViscosityValue;
    attribute def TorqueValue :> ISQ::TorqueValue;
    attribute def AngularVelocityValue :> ISQ::AngularVelocityValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def TimeValue :> ISQ::TimeValue;
    
    attribute def SpindleGeometryConstant :> Real {
        doc /* Dimensionless constant relating torque and angular velocity to viscosity for specific spindle geometry */
    }
    
    item def FluidSample {
        attribute viscosity : ViscosityValue;
        attribute temperature : TemperatureValue;
        attribute volume : VolumeValue;
    }
    
    port def PowerPort {
        in power : PowerValue;
    }
    
    port def SamplePort {
        in sample : FluidSample;
        out sample : FluidSample;
    }
    
    port def DataPort {
        out viscosity : ViscosityValue;
        out temperature : TemperatureValue;
    }
    
    port def ControlPort {
        in targetSpeed : AngularVelocityValue;
        in targetTemperature : TemperatureValue;
    }
    
    part def Motor {
        attribute commandSpeed : AngularVelocityValue;
        attribute actualSpeed : AngularVelocityValue;
        port powerIn : PowerPort;
        port controlIn : ControlPort;
    }
    
    part def Spindle {
        attribute geometryConstant : SpindleGeometryConstant;
        attribute rotationSpeed : AngularVelocityValue;
        attribute appliedTorque : TorqueValue;
    }
    
    part def TorqueSensor {
        attribute measuredTorque : TorqueValue;
        attribute calibrationFactor : Real;
    }
    
    part def TemperatureSensor {
        attribute measuredTemperature : TemperatureValue;
        attribute accuracy : TemperatureValue;
    }
    
    part def SampleChamber {
        attribute capacity : VolumeValue;
        attribute currentTemperature : TemperatureValue;
        attribute targetTemperature : TemperatureValue;
        attribute containedSample : FluidSample;
        port sampleInterface : SamplePort;
    }
    
    part def HeatingElement {
        attribute heatingPower : PowerValue;
        port powerIn : PowerPort;
    }
    
    part def TemperatureController {
        attribute setpoint : TemperatureValue;
        attribute tolerance : TemperatureValue;
        attribute controlGain : Real;
    }
    
    part def ProcessingUnit {
        attribute lastViscosityReading : ViscosityValue;
        attribute measurementCount : Integer;
    }
    
    part def DisplayUnit {
        attribute displayedViscosity : ViscosityValue;
        attribute displayedTemperature : TemperatureValue;
        port dataIn : DataPort;
    }
    
    part def DataLogger {
        attribute logInterval : TimeValue;
        attribute recordCount : Integer;
        port dataIn : DataPort;
    }
    
    action def LoadSample {
        in sampleVolume : VolumeValue;
        in sampleFluid : FluidSample;
        out loaded : Boolean;
    }
    
    action def StabilizeTemperature {
        in targetTemp : TemperatureValue;
        in tolerance : TemperatureValue;
        in currentTemp : TemperatureValue;
        out stabilized : Boolean;
        out finalTemp : TemperatureValue;
    }
    
    action def RotateSpindle {
        in targetSpeed : AngularVelocityValue;
        out actualSpeed : AngularVelocityValue;
        out status : Boolean;
    }
    
    action def MeasureTorque {
        in rotationSpeed : AngularVelocityValue;
        out torque : TorqueValue;
    }
    
    action def MeasureTemperature {
        out temperature : TemperatureValue;
    }
    
    action def CalculateViscosity {
        in torque : TorqueValue;
        in angularVelocity : AngularVelocityValue;
        in temperature : TemperatureValue;
        in geometryConstant : SpindleGeometryConstant;
        out viscosity : ViscosityValue;
    }
    
    action def DisplayResults {
        in viscosity : ViscosityValue;
        in temperature : TemperatureValue;
    }
    
    action def LogData {
        in viscosity : ViscosityValue;
        in temperature : TemperatureValue;
        in timestamp : TimeValue;
    }
    
    action def UnloadSample {
        out sample : FluidSample;
    }
    
    action def PerformViscosityMeasurement {
        in inputSample : FluidSample;
        in targetSpeed : AngularVelocityValue;
        in targetTemp : TemperatureValue;
        in geometryK : SpindleGeometryConstant;
        out measuredViscosity : ViscosityValue;
        out measurementTemp : TemperatureValue;
        
        private attribute loadedSample : FluidSample;
        private attribute stabilizedTemp : TemperatureValue;
        private attribute spindleSpeed : AngularVelocityValue;
        private attribute measuredTorque : TorqueValue;
        private attribute currentTemp : TemperatureValue;
        
        first start;
        then action load : LoadSample {
            in sampleVolume = inputSample.volume;
            in sampleFluid = inputSample;
            out loaded;
        }
        then decide loadCheck;
            if load.loaded then stabilize;
            else loadError;
        
        action stabilize : StabilizeTemperature {
            in targetTemp = PerformViscosityMeasurement::targetTemp;
            in tolerance = TemperatureValue(0.5, SI::K);
            in currentTemp = inputSample.temperature;
            out stabilized;
            out finalTemp;
        }
        then assign stabilizedTemp := stabilize.finalTemp;
        then action rotate : RotateSpindle {
            in targetSpeed = PerformViscosityMeasurement::targetSpeed;
            out actualSpeed;
            out status;
        }
        then assign spindleSpeed := rotate.actualSpeed;
        then action waitStabilization {
            doc /* Wait for fluid dynamics to stabilize */
        }
        then action measureT : MeasureTorque {
            in rotationSpeed = spindleSpeed;
            out torque;
        }
        then assign measuredTorque := measureT.torque;
        then action measureTemp : MeasureTemperature {
            out temperature;
        }
        then assign currentTemp := measureTemp.temperature;
        then action calculate : CalculateViscosity {
            in torque = measuredTorque;
            in angularVelocity = spindleSpeed;
            in temperature = currentTemp;
            in geometryConstant = PerformViscosityMeasurement::geometryK;
            out viscosity;
        }
        then action display : DisplayResults {
            in viscosity = calculate.viscosity;
            in temperature = currentTemp;
        }
        then action log : LogData {
            in viscosity = calculate.viscosity;
            in temperature = currentTemp;
            in timestamp;
        }
        then action unload : UnloadSample {
            out sample;
        }
        then action assignOutputs {
            assign measuredViscosity := calculate.viscosity;
            assign measurementTemp := currentTemp;
        }
        then done;
        
        action loadError;
        then done;
    }
    
    state def ViscosityMeasurementStates {
        entry; then idle;
        
        state idle {
            doc /* System ready to accept sample */
            accept SampleLoadedEvent;
            then loading;
        }
        
        state loading {
            doc /* Sample being loaded into chamber */
            do action loadFluid;
            then temperatureStabilization;
        }
        
        state temperatureStabilization {
            doc /* Heating sample to target temperature */
            do action heatSample;
            then measuring;
        }
        
        state measuring {
            doc /* Rotating spindle and measuring torque */
            do action performRotation;
            do action senseTorque;
            then computing;
        }
        
        state computing {
            doc /* Calculating viscosity from measurements */
            do action computeViscosity;
            then reporting;
        }
        
        state reporting {
            doc /* Displaying and logging results */
            do action showResults;
            do action recordData;
            then unloading;
        }
        
        state unloading {
            doc /* Removing sample from chamber */
            do action removeSample;
            then idle;
        }
    }
    
    part def Viscometer {
        doc /* 
            Primary function: Measure the dynamic viscosity of fluid samples by 
            rotating a calibrated spindle immersed in the sample at controlled 
            temperature and speed, measuring the resulting torque, and calculating 
            viscosity based on the relationship between shear stress and shear rate.
        */
        
        port powerSupply : PowerPort;
        port sampleAccess : SamplePort;
        port measurementOutput : DataPort;
        port systemControl : ControlPort;
        
        part motor : Motor {
            attribute commandSpeed = AngularVelocityValue(100.0, SI::RadianPerSecond);
        }
        
        part spindle : Spindle {
            attribute geometryConstant = 0.025;
        }
        
        part torqueSensor : TorqueSensor {
            attribute calibrationFactor = 1.0;
        }
        
        part tempSensor : TemperatureSensor {
            attribute accuracy = TemperatureValue(0.1, SI::K);
        }
        
        part chamber : SampleChamber {
            attribute capacity = VolumeValue(100.0, SI::ml);
            attribute targetTemperature = TemperatureValue(298.15, SI::K);
        }
        
        part heater : HeatingElement {
            attribute heatingPower = PowerValue(200.0, SI::W);
        }
        
        part tempController : TemperatureController {
            attribute tolerance = TemperatureValue(0.5, SI::K);
            attribute controlGain = 0.8;
        }
        
        part processor : ProcessingUnit {
            attribute measurementCount = 0;
        }
        
        part display : DisplayUnit;
        
        part logger : DataLogger {
            attribute logInterval = TimeValue(1.0, SI::s);
            attribute recordCount = 0;
        }
        
        connection powerToMotor connect powerSupply to motor.powerIn;
        connection powerToHeater connect powerSupply to heater.powerIn;
        connection sampleToChamber connect sampleAccess to chamber.sampleInterface;
        connection dataToDisplay connect measurementOutput to display.dataIn;
        connection dataToLogger connect measurementOutput to logger.dataIn;
        connection controlToMotor connect systemControl to motor.controlIn;
        
        perform action measureViscosity[*] : PerformViscosityMeasurement {
            in inputSample;
            in targetSpeed = motor.commandSpeed;
            in targetTemp = chamber.targetTemperature;
            in geometryK = spindle.geometryConstant;
            out measuredViscosity;
            out measurementTemp;
        }
        
        state operationalStates : ViscosityMeasurementStates;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def AccuracyRequirement;
    requirement def TemperatureControlRequirement;
    requirement def MeasurementRangeRequirement;
    
    requirement <'VIS-REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* 
            The Viscometer shall measure the dynamic viscosity of fluid samples 
            by controlled rotational shear analysis, providing accurate viscosity 
            values for quality control, research, and process monitoring applications.
        */
        subject viscosityMeasurementSystem : Viscometer;
    }
    
    requirement <'VIS-REQ-002'> measurementAccuracy : AccuracyRequirement {
        doc /* 
            The Viscometer shall measure viscosity with an accuracy of ±1% of 
            reading over the full measurement range.
        */
        refines primaryFunction;
        subject measuredViscosity : ViscosityValue;
    }
    
    requirement <'VIS-REQ-003'> temperatureStability : TemperatureControlRequirement {
        doc /* 
            The Viscometer shall maintain sample temperature within ±0.5°C of 
            the setpoint during measurement.
        */
        refines primaryFunction;
        subject sampleTemperature : TemperatureValue;
    }
    
    requirement <'VIS-REQ-004'> viscosityRange : MeasurementRangeRequirement {
        doc /* 
            The Viscometer shall measure viscosity over a range from 1 to 100000 
            centipoise (0.001 to 100 Pa·s).
        */
        refines primaryFunction;
        subject viscosityMeasurementRange : ViscosityValue;
    }
    
    requirement <'VIS-REQ-005'> repeatability : PerformanceRequirement {
        doc /* 
            The Viscometer shall provide repeatable measurements with a coefficient 
            of variation less than 0.5% for consecutive measurements of the same sample.
        */
        refines measurementAccuracy;
    }
    
    part viscometerSystem : Viscometer {
        satisfy primaryFunction by measureViscosity;
        satisfy measurementAccuracy by processor;
        satisfy temperatureStability by tempController;
        satisfy viscosityRange by spindle;
    }
}
