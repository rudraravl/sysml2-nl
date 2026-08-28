package MedicalVideoLaryngoscopySystem {
    import ScalarValues::*;
    import ISQ::*;
    
    value type PowerUnit > Real { unit "W"; }
    value type VoltageUnit > Real { unit "V"; }
    value type TemperatureUnit > Real { unit "degC"; }
    value type ForceUnit > Real { unit "N"; }
    value type ResolutionWidth > Integer;
    value type ResolutionHeight > Integer;
    value type DurationHours > Real { unit "h"; }
    
    item def Power {
        attribute voltage : VoltageUnit;
        attribute current : Real;
    }
    
    item def VideoSignal {
        attribute width : ResolutionWidth = 1920;
        attribute height : ResolutionHeight = 1080;
        attribute frameRate : Real = 30;
    }
    
    port def PowerOut {
        out power : Power;
    }
    
    port def PowerIn {
        in power : Power;
    }
    
    port def VideoOut {
        out video : VideoSignal;
    }
    
    port def VideoIn {
        in video : VideoSignal;
    }
    
    requirement def BatteryLifeRequirement {
        attribute minDuration : DurationHours = 2.0;
        requirement constraint { batteryDuration >= minDuration }
    }
    
    requirement def ImageQualityRequirement {
        attribute reqWidth : ResolutionWidth = 1920;
        attribute reqHeight : ResolutionHeight = 1080;
        requirement constraint { video.width >= reqWidth and video.height >= reqHeight }
    }
    
    requirement def SafetyRequirements {
        attribute maxTissueForce : ForceUnit = 30.0;
        attribute maxTipTemperature : TemperatureUnit = 41.0;
        requirement constraint { appliedForce <= maxTissueForce }
        requirement constraint { tipTemperature <= maxTipTemperature }
    }
    
    requirement def SterilizationRequirement {
        attribute isSterilizable : Boolean = true;
        requirement constraint { patientContactComponent.isSterilizable == true }
    }
    
    part def HandleUnit {
        attribute batteryDuration : DurationHours;
        port powerOut : PowerOut[1];
        
        part battery {
            attribute capacity : Real;
        }
        
        part powerRegulator {
            attribute outputVoltage : VoltageUnit = 5.0;
        }
        
        satisfy BatteryLifeRequirement by batteryDuration;
    }
    
    part def LightingModule {
        port powerIn : PowerIn[1];
        attribute intensity : Real;
        attribute colorTemperature : Real;
        attribute tipTemperature : TemperatureUnit;
        
        satisfy SafetyRequirements by tipTemperature;
    }
    
    part def OpticalChannel {
        port powerIn : PowerIn[1];
        port videoOut : VideoOut[1];
        
        part lensAssembly {
            attribute viewingAngle : Real = 90.0;
        }
        
        part imageProcessor {
            attribute video : VideoSignal;
        }
        
        satisfy ImageQualityRequirement by imageProcessor.video;
    }
    
    part def BladeAssembly {
        attribute length : Real;
        attribute curvature : Real;
        attribute appliedForce : ForceUnit;
        attribute isSterilizable : Boolean = true;
        
        part lightingModule : LightingModule;
        part opticalChannel : OpticalChannel;
        
        satisfy SafetyRequirements by appliedForce;
        satisfy SterilizationRequirement by isSterilizable;
    }
    
    part def HandheldLaryngoscope {
        part handleUnit : HandleUnit;
        part bladeAssembly : BladeAssembly;
        
        connection powerToLighting connect handleUnit.powerOut to bladeAssembly.lightingModule.powerIn;
        connection powerToOptical connect handleUnit.powerOut to bladeAssembly.opticalChannel.powerIn;
    }
    
    part def VideoDisplay {
        port videoIn : VideoIn[1];
        attribute screenSize : Real;
    }
    
    state def OperatingProcedure {
        entry action startUp;
        
        state Preparation {
            entry action checkBattery;
            do action checkSystem;
        }
        
        state Insertion {
            entry action insertBlade;
            do action displaceTissue;
        }
        
        state ActiveVisualization {
            entry action activateLightCamera;
            do action assessAnatomy;
            do action documentFindings;
        }
        
        state Withdrawal {
            entry action deactivateLightCamera;
            do action withdrawBlade;
        }
        
        transition from Preparation to Insertion when batteryChecked;
        transition from Insertion to ActiveVisualization when bladeInserted;
        transition from ActiveVisualization to Withdrawal when assessmentComplete;
        transition from Withdrawal to Preparation when bladeWithdrawn;
    }
    
    part def MedicalVideoLaryngoscopySystem {
        part handheldLaryngoscope : HandheldLaryngoscope;
        part videoDisplay : VideoDisplay;
        
        connection videoToDisplay connect handheldLaryngoscope.bladeAssembly.opticalChannel.videoOut to videoDisplay.videoIn;
        
        state operatingProcedure : OperatingProcedure;
    }
}
