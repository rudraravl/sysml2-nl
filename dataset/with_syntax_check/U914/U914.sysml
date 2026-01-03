package 'ThinFilmThicknessMonitorSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MaterialProperties {
        attribute density : DensityValue;
        attribute acousticImpedance : Real;
        attribute toolingFactor : Real;
    }
    
    attribute def MonitoringParameters {
        attribute targetThickness : LengthValue;
        attribute thicknessTolerance : LengthValue;
        attribute maxDepositionRate : SpeedValue;
    }
    
    attribute def ShutterCommand {
        attribute open : Boolean;
    }
    
    port def SensorPort {
        out attribute crystalFrequency : FrequencyValue;
        out attribute crystalTemperature : ThermodynamicTemperatureValue;
    }
    
    port def ControlPort {
        in attribute startDeposition : Boolean;
        in attribute stopDeposition : Boolean;
        out attribute shutterCommand : ShutterCommand;
        out attribute processComplete : Boolean;
    }
    
    port def DisplayPort {
        out attribute currentThickness : LengthValue;
        out attribute depositionRate : SpeedValue;
        out attribute remainingThickness : LengthValue;
    }
    
    part def QuartzCrystalSensor {
        attribute baseFrequency : FrequencyValue;
        attribute currentFrequency : FrequencyValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute crystalArea : AreaValue;
        
        port sensorOutput : SensorPort;
        
        action def MeasureFrequency {
            out frequency : FrequencyValue;
            out temp : ThermodynamicTemperatureValue;
        }
    }
    
    part def FrequencyCounter {
        in attribute inputFrequency : FrequencyValue;
        out attribute measuredFrequency : FrequencyValue;
        attribute resolution : FrequencyValue;
        
        action def CountFrequency {
            in freq : FrequencyValue;
            out result : FrequencyValue;
        }
    }
    
    part def ThicknessCalculator {
        in attribute frequencyShift : FrequencyValue;
        in attribute materialProps : MaterialProperties;
        out attribute calculatedThickness : LengthValue;
        out attribute depositionRate : SpeedValue;
        
        action def CalculateThickness {
            in deltaFreq : FrequencyValue;
            in density : DensityValue;
            in toolingFactor : Real;
            out thickness : LengthValue;
        }
        
        action def CalculateRate {
            in thicknessChange : LengthValue;
            in timeInterval : TimeValue;
            out rate : SpeedValue;
        }
    }
    
    part def ProcessController {
        in attribute currentThickness : LengthValue;
        in attribute targetThickness : LengthValue;
        in attribute tolerance : LengthValue;
        out attribute shutterControl : ShutterCommand;
        out attribute alarmStatus : Boolean;
        
        port controlInterface : ControlPort;
        
        action def MonitorProcess {
            in thickness : LengthValue;
            in target : LengthValue;
            in tol : LengthValue;
            out shutter : ShutterCommand;
            out alarm : Boolean;
        }
    }
    
    part def DisplayUnit {
        in attribute thickness : LengthValue;
        in attribute rate : SpeedValue;
        in attribute remaining : LengthValue;
        
        port displayOutput : DisplayPort;
        
        action def UpdateDisplay {
            in currentValue : LengthValue;
            in rateValue : SpeedValue;
        }
    }
    
    part def ThinFilmThicknessMonitor {
        attribute materialProperties : MaterialProperties;
        attribute monitoringParams : MonitoringParameters;
        
        part crystalSensor : QuartzCrystalSensor {
            attribute :>> baseFrequency = 6000000.0 [Hz];
        }
        
        part frequencyCounter : FrequencyCounter {
            attribute :>> resolution = 0.1 [Hz];
        }
        
        part thicknessCalc : ThicknessCalculator;
        
        part processCtrl : ProcessController;
        
        part display : DisplayUnit;
        
        connection crystalToCounter connect 
            crystalSensor.sensorOutput.crystalFrequency to 
            frequencyCounter.inputFrequency;
        
        connection counterToCalculator connect 
            frequencyCounter.measuredFrequency to 
            thicknessCalc.frequencyShift;
        
        connection calculatorToController connect 
            thicknessCalc.calculatedThickness to 
            processCtrl.currentThickness;
        
        connection calculatorToDisplay connect 
            thicknessCalc.calculatedThickness to 
            display.thickness;
        
        connection rateToDisplay connect 
            thicknessCalc.depositionRate to 
            display.rate;
        
        perform action monitorThinFilmDeposition;
    }
    
    action def MonitorThinFilmDeposition {
        in attribute materialProps : MaterialProperties;
        in attribute targetThickness : LengthValue;
        in attribute tolerance : LengthValue;
        out attribute finalThickness : LengthValue;
        out attribute processStatus : Boolean;
    }
    
    action monitorThinFilmDeposition : MonitorThinFilmDeposition {
        in attribute materialProps : MaterialProperties;
        in attribute targetThickness : LengthValue;
        in attribute tolerance : LengthValue;
        out attribute finalThickness : LengthValue;
        out attribute processStatus : Boolean;
        
        first start;
        then action initializeSystem {
            action setMaterialProperties {
                out props : MaterialProperties;
            }
            then action calibrateCrystal {
                in baseProps : MaterialProperties;
                out baselineFrequency : FrequencyValue;
            }
            then action setTargetParameters {
                in target : LengthValue;
                out params : MonitoringParameters;
            }
        }
        
        then merge monitoringLoop;
        
        then action monitoringCycle {
            action measureFrequency {
                out currentFreq : FrequencyValue;
                out crystalTemp : ThermodynamicTemperatureValue;
            }
            
            flow measureFrequency.currentFreq to calculateThickness.frequency;
            
            action calculateThickness {
                in frequency : FrequencyValue;
                in material : MaterialProperties;
                out thickness : LengthValue;
                out rate : SpeedValue;
            }
            
            flow calculateThickness.thickness to evaluateProgress.current;
            flow calculateThickness.rate to updateDisplay.rateValue;
            
            action evaluateProgress {
                in current : LengthValue;
                in target : LengthValue;
                in tol : LengthValue;
                out continueDeposition : Boolean;
                out shutterCmd : ShutterCommand;
            }
            
            action updateDisplay {
                in thicknessValue : LengthValue;
                in rateValue : SpeedValue;
            }
        }
        
        then decide;
            if monitoringCycle.evaluateProgress.continueDeposition then monitoringLoop;
            if !monitoringCycle.evaluateProgress.continueDeposition then finalizeProcess;
        
        action finalizeProcess {
            action closeShutter {
                out shutterClosed : ShutterCommand;
            }
            then action recordFinalThickness {
                in measured : LengthValue;
                out final : LengthValue;
            }
            then action generateReport {
                in finalValue : LengthValue;
                in targetValue : LengthValue;
                out status : Boolean;
            }
        }
        
        then done;
    }
    
    requirement <'TFTM-001'> monitoringAccuracyRequirement {
        doc /* The thin-film thickness monitor shall measure film thickness 
             with an accuracy of +/- 0.1 nanometers for films up to 1000 nanometers. */
        
        subject monitor : ThinFilmThicknessMonitor;
    }
    
    requirement <'TFTM-002'> depositionControlRequirement {
        doc /* The system shall automatically terminate deposition when the target 
             thickness is reached within the specified tolerance. */
        
        subject controller : ProcessController;
    }
    
    requirement <'TFTM-003'> realTimeMonitoringRequirement {
        doc /* The system shall provide real-time thickness and deposition rate 
             measurements with update frequency of at least 10 Hz. */
        
        subject system : ThinFilmThicknessMonitor;
    }
    
    requirement systemRequirements {
        doc /* The thin-film thickness monitor system shall accurately measure and 
             control the deposition of thin films in vacuum coating processes. */
        
        require monitoringAccuracyRequirement;
        require depositionControlRequirement;
        require realTimeMonitoringRequirement;
    }
}
