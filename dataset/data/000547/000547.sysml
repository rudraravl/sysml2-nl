package BiliblanketPhototherapySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BilirubinConcentration :> Real {
        doc /* Serum bilirubin level in mg/dL */
    }
    
    attribute def SpectralIrradiance :> Real {
        doc /* Light irradiance in μW/cm²/nm */
    }
    
    attribute def WavelengthSpec :> Real {
        attribute peakWavelength : LengthValue;
        attribute minWavelength : LengthValue;
        attribute maxWavelength : LengthValue;
    }
    
    item def TherapeuticLight {
        attribute irradiance : SpectralIrradiance;
        attribute wavelength : WavelengthSpec;
        attribute power : PowerValue;
    }
    
    item def ElectricalPower {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    item def ControlSignal {
        attribute intensityLevel : Real;
        attribute enabled : Boolean;
        attribute timerRemaining : TimeValue;
    }
    
    item def ThermalData {
        attribute surfaceTemperature : ThermodynamicTemperatureValue;
        attribute ambientTemperature : ThermodynamicTemperatureValue;
    }
    
    port def PowerPort {
        in electricalPower : ElectricalPower;
    }
    
    port def LightPort {
        out therapeuticLight : TherapeuticLight;
    }
    
    port def ControlPort {
        in controlSignal : ControlSignal;
    }
    
    port def ThermalPort {
        out thermalData : ThermalData;
    }
    
    requirement def TherapeuticEfficacy {
        doc /* System shall deliver effective phototherapy for neonatal hyperbilirubinemia */
        
        require constraint irradianceRequirement {
            doc /* Minimum spectral irradiance of 30 μW/cm²/nm at treatment surface */
        }
        
        require constraint wavelengthRequirement {
            doc /* Blue-green light with peak wavelength between 460-490 nm */
        }
        
        require constraint coverageRequirement {
            doc /* Treatment area shall cover minimum 600 cm² of infant body surface */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* System shall ensure patient safety during phototherapy */
        
        require constraint temperatureLimit {
            doc /* Pad surface temperature shall not exceed 38°C */
        }
        
        require constraint electricalIsolation {
            doc /* Electrical isolation shall meet IEC 60601-1 medical device standards */
        }
        
        require constraint autoShutoff {
            doc /* System shall automatically shut off upon temperature or timer limit */
        }
    }
    
    requirement <'REQ-001'> systemEfficacy : TherapeuticEfficacy {
        subject biliblanketSystem;
    }
    
    requirement <'REQ-002'> systemSafety : SafetyRequirement {
        subject biliblanketSystem;
    }
    
    part def PowerSupply {
        attribute inputVoltage : ElectricPotentialValue := 120.0 [V];
        attribute outputVoltage : ElectricPotentialValue := 24.0 [V];
        attribute maxOutputPower : PowerValue := 35.0 [W];
        
        port acInput : PowerPort;
        port dcOutput : PowerPort;
    }
    
    part def LEDLightEngine {
        attribute peakWavelengthNominal : LengthValue := 475.0e-9 [m];
        attribute nominalIrradiance : SpectralIrradiance := 35.0;
        attribute operatingPower : PowerValue := 25.0 [W];
        attribute efficiency : Real := 0.75;
        
        port powerInput : PowerPort;
        port controlInput : ControlPort;
        port lightOutput : LightPort;
    }
    
    part def FiberOpticPad {
        attribute padArea : AreaValue := 0.06 [m^2];
        attribute transmissionEfficiency : Real := 0.88;
        attribute thermalConductivity : Real := 0.15;
        
        port lightInput : LightPort;
        port patientSurface : LightPort;
        port thermalOutput : ThermalPort;
    }
    
    part def ControlModule {
        attribute intensitySetting : Real := 100.0;
        attribute treatmentDuration : TimeValue := 24.0 [h];
        attribute elapsedTime : TimeValue := 0.0 [h];
        attribute maxSafeTemperature : ThermodynamicTemperatureValue := 311.15 [K];
        
        port powerInput : PowerPort;
        port controlOutput : ControlPort;
        port thermalInput : ThermalPort;
        port userInterface;
    }
    
    part def TemperatureSensor {
        attribute currentTemperature : ThermodynamicTemperatureValue;
        attribute sensorAccuracy : ThermodynamicTemperatureValue := 0.5 [K];
        
        port thermalSense : ThermalPort;
    }
    
    action def MonitorBilirubin {
        in initialLevel : BilirubinConcentration;
        out currentLevel : BilirubinConcentration;
        out requiresTreatment : Boolean;
    }
    
    action def ActivatePhototherapy {
        in intensity : Real;
        in duration : TimeValue;
        out lightDelivered : TherapeuticLight;
    }
    
    action def MonitorSafety {
        in surfaceTemp : ThermodynamicTemperatureValue;
        in maxTemp : ThermodynamicTemperatureValue;
        out safeToOperate : Boolean;
    }
    
    action def DeactivatePhototherapy {
        out shutdownComplete : Boolean;
    }
    
    action def DeliverPhototherapy {
        in patientBilirubinLevel : BilirubinConcentration;
        in prescribedIntensity : Real;
        in prescribedDuration : TimeValue;
        out treatmentComplete : Boolean;
        
        private attribute bilirubinThreshold : BilirubinConcentration := 5.0;
        
        first start;
        then merge evaluateConditions;
        
        then action assessBilirubin : MonitorBilirubin {
            in initialLevel = patientBilirubinLevel;
            out currentLevel;
            out requiresTreatment;
        }
        
        then decide;
            if assessBilirubin.requiresTreatment and assessBilirubin.currentLevel > bilirubinThreshold 
                then initiateTherapy;
            if not assessBilirubin.requiresTreatment or assessBilirubin.currentLevel <= bilirubinThreshold 
                then terminateTherapy;
        
        action initiateTherapy : ActivatePhototherapy {
            in intensity = prescribedIntensity;
            in duration = prescribedDuration;
            out lightDelivered;
        }
        
        then action checkSafety : MonitorSafety {
            in surfaceTemp;
            in maxTemp;
            out safeToOperate;
        }
        
        then decide;
            if checkSafety.safeToOperate then evaluateConditions;
            if not checkSafety.safeToOperate then emergencyShutdown;
        
        action emergencyShutdown : DeactivatePhototherapy {
            out shutdownComplete;
        }
        then done;
        
        action terminateTherapy : DeactivatePhototherapy {
            out shutdownComplete;
        }
        then assign treatmentComplete := true;
        then done;
    }
    
    state def TherapyControlState {
        entry start;
        
        state Standby;
        
        transition standbyToActive
            first Standby
            accept startCommand
            then Active;
        
        state Active {
            entry action enableLight;
            
            state Monitoring;
            
            transition monitoringToTreating
                first Monitoring
                accept parametersValid
                then Treating;
            
            state Treating;
            
            transition treatingToMonitoring
                first Treating
                accept cycleComplete
                then Monitoring;
            
            transition treatingToAlarm
                first Treating
                accept overTemperature
                then TemperatureAlarm;
            
            state TemperatureAlarm {
                entry action disableLight;
            }
            
            transition alarmToStandby
                first TemperatureAlarm
                accept resetCommand
                then Standby;
        }
        
        transition activeToStandbyStop
            first Active
            accept stopCommand
            then Standby;
        
        transition activeToStandbyTimer
            first Active
            accept timerExpired
            then Standby;
    }
    
    part biliblanketSystem : BiliblanketDevice {
        doc /* 
            Biliblanket phototherapy system for treatment of neonatal jaundice.
            
            Primary Function: Deliver controlled blue-green light phototherapy to reduce 
            elevated serum bilirubin levels in newborns through a flexible fiber optic 
            blanket that wraps around the infant, providing safe and effective treatment 
            while allowing normal infant care activities to continue.
        */
        
        satisfy systemEfficacy, systemSafety;
        
        attribute systemStatus : String;
        attribute operationalMode : String;
        
        part powerSupply : PowerSupply {
            attribute :>> inputVoltage = 120.0 [V];
            attribute :>> outputVoltage = 24.0 [V];
            attribute :>> maxOutputPower = 35.0 [W];
        }
        
        part ledEngine : LEDLightEngine {
            attribute :>> peakWavelengthNominal = 475.0e-9 [m];
            attribute :>> nominalIrradiance = 35.0;
            attribute :>> operatingPower = 25.0 [W];
        }
        
        part fiberPad : FiberOpticPad {
            attribute :>> padArea = 0.06 [m^2];
            attribute :>> transmissionEfficiency = 0.88;
        }
        
        part controller : ControlModule {
            attribute :>> intensitySetting = 100.0;
            attribute :>> treatmentDuration = 24.0 [h];
            attribute :>> maxSafeTemperature = 311.15 [K];
        }
        
        part tempSensor : TemperatureSensor {
            attribute :>> currentTemperature = 309.15 [K];
        }
        
        connection powerToDC connect powerSupply.dcOutput to controller.powerInput;
        connection powerToLED connect powerSupply.dcOutput to ledEngine.powerInput;
        connection controlToLED connect controller.controlOutput to ledEngine.controlInput;
        connection lightToFiber connect ledEngine.lightOutput to fiberPad.lightInput;
        connection tempToController connect tempSensor.thermalSense to controller.thermalInput;
        connection tempFromPad connect fiberPad.thermalOutput to tempSensor.thermalSense;
        
        port mainsInput : PowerPort;
        port therapyOutput : LightPort;
        port userControl;
        
        exhibit state therapyState : TherapyControlState;
        
        perform action phototherapyTreatment : DeliverPhototherapy {
            in patientBilirubinLevel;
            in prescribedIntensity;
            in prescribedDuration;
            out treatmentComplete;
        }
    }
    
    part def BiliblanketDevice;
}
