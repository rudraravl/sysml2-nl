package MagneticLevelGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def LevelPercentage :> Real;
    attribute def MagneticCouplingStrength :> Real;
    
    item def ProcessFluid {
        attribute density : DensityValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute pressure : PressureValue;
        attribute viscosity : Real;
    }
    
    item def LevelMeasurement {
        attribute height : LengthValue;
        attribute percentage : LevelPercentage;
        attribute timestamp : TimeValue;
        attribute isValid : Boolean;
    }
    
    item def AlarmSignal {
        attribute isActive : Boolean;
        attribute alarmType : AlarmType;
        attribute setpoint : LengthValue;
    }
    
    enum def AlarmType {
        highLevel;
        lowLevel;
        fault;
    }
    
    port def FluidPort {
        in attribute fluidLevel : LengthValue;
        in item processFluid : ProcessFluid;
    }
    
    port def IndicatorPort {
        out item levelData : LevelMeasurement;
    }
    
    port def AlarmPort {
        out item alarmSignal : AlarmSignal;
    }
    
    port def AnalogOutputPort {
        out attribute signalCurrent : ElectricCurrentValue;
    }
    
    part def MagneticFloat {
        attribute position : LengthValue;
        attribute magneticStrength : MagneticCouplingStrength;
        attribute buoyantForce : ForceValue;
        
        port fluidInterface : FluidPort;
        
        action trackLevel {
            in fluidLevel : LengthValue;
            in fluidDensity : DensityValue;
            out floatPosition : LengthValue;
            
            first start;
            then action calculateBuoyancy {
                in density = fluidDensity;
                out force : ForceValue;
            }
            then action determinePosition {
                in level = fluidLevel;
                in buoyancy = calculateBuoyancy.force;
                out newPosition : LengthValue;
            }
            then assign position := determinePosition.newPosition;
            then done;
        }
    }
    
    part def IndicatorAssembly {
        attribute displayedLevel : LengthValue;
        attribute scaleMin : LengthValue;
        attribute scaleMax : LengthValue;
        
        port indicatorOutput : IndicatorPort;
        
        action updateIndication {
            in floatPosition : LengthValue;
            in rangeMin : LengthValue;
            in rangeMax : LengthValue;
            out measurement : LevelMeasurement;
            
            first start;
            then action calculatePercentage {
                in position = floatPosition;
                in min = rangeMin;
                in max = rangeMax;
                out percent : LevelPercentage;
            }
            then action validateReading {
                in position = floatPosition;
                in percent = calculatePercentage.percent;
                out valid : Boolean;
            }
            then action createMeasurement {
                in level = floatPosition;
                in percentage = calculatePercentage.percent;
                in validity = validateReading.valid;
                out reading : LevelMeasurement;
            }
            then assign displayedLevel := floatPosition;
            then assign measurement := createMeasurement.reading;
            then done;
        }
    }
    
    part def LevelTransmitter {
        attribute outputCurrent : ElectricCurrentValue;
        attribute calibrationZero : LengthValue;
        attribute calibrationSpan : LengthValue;
        
        port analogOut : AnalogOutputPort;
        
        action convertToSignal {
            in levelPosition : LengthValue;
            in zeroPoint : LengthValue;
            in spanRange : LengthValue;
            out current : ElectricCurrentValue;
            
            first start;
            then action normalizeLevel {
                in position = levelPosition;
                in zero = zeroPoint;
                in span = spanRange;
                out normalized : Real;
            }
            then action scaleToMilliamps {
                in normalizedValue = normalizeLevel.normalized;
                out milliamps : ElectricCurrentValue;
            }
            then assign outputCurrent := scaleToMilliamps.milliamps;
            then assign analogOut.signalCurrent := scaleToMilliamps.milliamps;
            then done;
        }
    }
    
    part def AlarmSwitch {
        attribute setpoint : LengthValue;
        attribute hysteresis : LengthValue;
        attribute alarmState : Boolean;
        attribute currentLevel : LengthValue;
        
        port alarmOutput : AlarmPort;
        
        action def MonitorAlarmCondition {
            in level : LengthValue;
            in threshold : LengthValue;
            in hyst : LengthValue;
            in currentState : Boolean;
            out newState : Boolean;
        }
        
        action checkAlarm {
            in measuredLevel : LengthValue;
            out alarmActive : Boolean;
            
            first start;
            then action monitor : MonitorAlarmCondition {
                in level = measuredLevel;
                in threshold = setpoint;
                in hyst = hysteresis;
                in currentState = alarmState;
                out newState;
            }
            then assign currentLevel := measuredLevel;
            then assign alarmState := monitor.newState;
            then assign alarmActive := monitor.newState;
            then done;
        }
    }
    
    part def BypassChamber {
        attribute chamberDiameter : LengthValue;
        attribute chamberLength : LengthValue;
        
        port topConnection : FluidPort;
        port bottomConnection : FluidPort;
        port floatCavity;
        
        action maintainFluidCommunication {
            in topFluidLevel : LengthValue;
            in bottomFluidLevel : LengthValue;
            out chamberLevel : LengthValue;
            
            first start;
            then action equalizeLevel {
                in topLevel = topFluidLevel;
                in bottomLevel = bottomFluidLevel;
                out equilibriumLevel : LengthValue;
            }
            then assign chamberLevel := equalizeLevel.equilibriumLevel;
            then done;
        }
    }
    
    part def MagneticLevelGauge {
        doc /* A magnetic level gauge that uses magnetic coupling between a float 
               and external indicator to provide continuous level measurement without 
               direct contact with the process fluid. */
        
        attribute measuringRange : LengthValue;
        attribute processConnection : String;
        attribute materialOfConstruction : String;
        
        port vesselTopPort : FluidPort;
        port vesselBottomPort : FluidPort;
        port visualIndicatorPort : IndicatorPort;
        port transmitterPort : AnalogOutputPort;
        port highAlarmPort : AlarmPort;
        port lowAlarmPort : AlarmPort;
        
        part bypassChamber : BypassChamber {
            :>> chamberDiameter = 50.0 [mm];
            :>> chamberLength = 3000.0 [mm];
        }
        
        part magneticFloat : MagneticFloat {
            :>> magneticStrength = 1.0;
        }
        
        part visualIndicator : IndicatorAssembly {
            :>> scaleMin = 0.0 [mm];
            :>> scaleMax = 3000.0 [mm];
        }
        
        part transmitter : LevelTransmitter {
            :>> calibrationZero = 0.0 [mm];
            :>> calibrationSpan = 3000.0 [mm];
        }
        
        part highLevelAlarm : AlarmSwitch {
            :>> setpoint = 2700.0 [mm];
            :>> hysteresis = 50.0 [mm];
        }
        
        part lowLevelAlarm : AlarmSwitch {
            :>> setpoint = 300.0 [mm];
            :>> hysteresis = 50.0 [mm];
        }
        
        connection chamberToVesselTop connect bypassChamber.topConnection to vesselTopPort;
        connection chamberToVesselBottom connect bypassChamber.bottomConnection to vesselBottomPort;
        connection floatToChamber connect magneticFloat.fluidInterface to bypassChamber.floatCavity;
        connection indicatorToOutput connect visualIndicator.indicatorOutput to visualIndicatorPort;
        connection transmitterToOutput connect transmitter.analogOut to transmitterPort;
        connection highAlarmToOutput connect highLevelAlarm.alarmOutput to highAlarmPort;
        connection lowAlarmToOutput connect lowLevelAlarm.alarmOutput to lowAlarmPort;
        
        action performLevelMeasurement {
            doc /* Primary function: Continuously measure and indicate fluid level 
                   by magnetically coupling the position of a buoyant float to 
                   external indicators and transmitters. */
            
            first start;
            then merge continuousMeasurement;
            
            then action trackFloatPosition : MagneticFloat::trackLevel {
                in fluidLevel = vesselTopPort.fluidLevel;
                in fluidDensity = vesselTopPort.processFluid.density;
                out floatPosition;
            }
            
            then fork parallelProcessing;
            
            action updateVisualDisplay : IndicatorAssembly::updateIndication {
                in floatPosition = trackFloatPosition.floatPosition;
                in rangeMin = visualIndicator.scaleMin;
                in rangeMax = visualIndicator.scaleMax;
                out measurement;
            }
            
            action generateAnalogSignal : LevelTransmitter::convertToSignal {
                in levelPosition = trackFloatPosition.floatPosition;
                in zeroPoint = transmitter.calibrationZero;
                in spanRange = transmitter.calibrationSpan;
                out current;
            }
            
            action checkHighAlarm : AlarmSwitch::checkAlarm {
                in measuredLevel = trackFloatPosition.floatPosition;
                out alarmActive;
            }
            
            action checkLowAlarm : AlarmSwitch::checkAlarm {
                in measuredLevel = trackFloatPosition.floatPosition;
                out alarmActive;
            }
            
            then join parallelProcessing;
            then continuousMeasurement;
        }
    }
    
    part def ProcessVessel {
        attribute capacity : VolumeValue;
        attribute currentLevel : LengthValue;
        attribute operatingPressure : PressureValue;
        attribute operatingTemperature : ThermodynamicTemperatureValue;
        
        port topNozzle : FluidPort;
        port bottomNozzle : FluidPort;
        
        attribute containedFluid : ProcessFluid;
    }
    
    part magneticLevelGaugeSystem {
        doc /* Complete magnetic level gauge installation on a process vessel. */
        
        part gauge : MagneticLevelGauge {
            :>> measuringRange = 3000.0 [mm];
            :>> processConnection = "ANSI 150# RF";
            :>> materialOfConstruction = "316 Stainless Steel";
        }
        
        part vessel : ProcessVessel {
            :>> capacity = 15000.0 [L];
            :>> currentLevel = 1500.0 [mm];
            :>> operatingPressure = 10.0 [bar];
            :>> operatingTemperature = 80.0 [Celsius];
            
            :>> containedFluid.density = 1000.0 [kg/m^3];
            :>> containedFluid.temperature = 80.0 [Celsius];
            :>> containedFluid.pressure = 10.0 [bar];
        }
        
        connection vesselToGaugeTop connect vessel.topNozzle to gauge.vesselTopPort;
        connection vesselToGaugeBottom connect vessel.bottomNozzle to gauge.vesselBottomPort;
        
        bind gauge.magneticFloat.fluidInterface.fluidLevel = vessel.currentLevel;
        bind gauge.magneticFloat.fluidInterface.processFluid = vessel.containedFluid;
        
        perform action continuousMonitoring[*] ordered references gauge.performLevelMeasurement;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The gauge shall provide accurate level measurement within specified tolerance. */
        attribute accuracy : Real;
        attribute operatingRange : LengthValue;
    }
    
    requirement def VisualIndicationRequirement {
        doc /* The gauge shall provide continuous visual indication of level. */
        attribute readabilityDistance : LengthValue;
        attribute scaleResolution : LengthValue;
    }
    
    requirement def RemoteMonitoringRequirement {
        doc /* The gauge shall provide remote level monitoring capability. */
        attribute signalType : String;
        attribute signalRange : ElectricCurrentValue[2];
    }
    
    requirement def SafetyRequirement {
        doc /* The gauge shall operate safely in process conditions. */
        attribute maxPressure : PressureValue;
        attribute maxTemperature : ThermodynamicTemperatureValue;
        attribute materialCompatibility : String;
    }
    
    requirement <'MLG-REQ-001'> accuracyRequirement : MeasurementAccuracyRequirement {
        :>> accuracy = 0.01;
        :>> operatingRange = 3000.0 [mm];
        
        subject magneticLevelGaugeSystem.gauge;
        
        require constraint {
            doc /* Measurement error shall not exceed ±1% of full scale. */
        }
    }
    
    requirement <'MLG-REQ-002'> visualRequirement : VisualIndicationRequirement {
        :>> readabilityDistance = 10.0 [m];
        :>> scaleResolution = 10.0 [mm];
        
        subject magneticLevelGaugeSystem.gauge.visualIndicator;
        
        require constraint {
            doc /* Visual indication shall be readable from 10 meters distance. */
        }
    }
    
    requirement <'MLG-REQ-003'> remoteRequirement : RemoteMonitoringRequirement {
        :>> signalType = "4-20 mA";
        :>> signalRange = (4.0 [mA], 20.0 [mA]);
        
        subject magneticLevelGaugeSystem.gauge.transmitter;
        
        require constraint {
            doc /* Analog output shall provide 4-20 mA signal proportional to level. */
        }
    }
    
    requirement <'MLG-REQ-004'> safetyRequirement : SafetyRequirement {
        :>> maxPressure = 40.0 [bar];
        :>> maxTemperature = 200.0 [Celsius];
        :>> materialCompatibility = "Compatible with corrosive fluids";
        
        subject magneticLevelGaugeSystem.gauge;
        
        require constraint {
            doc /* Gauge shall withstand process conditions without failure. */
        }
    }
    
    requirement <'MLG-SYS-FUNC'> primarySystemFunction {
        doc /* The magnetic level gauge system shall continuously measure and indicate 
               the level of fluid in a process vessel by magnetically coupling a buoyant 
               float inside a bypass chamber to external indicators and transmitters, 
               providing visual indication, analog signal output, and alarm functions 
               without requiring direct contact between measuring elements and process fluid. */
        
        subject magneticLevelGaugeSystem;
        
        assume constraint vesselContainsFluid {
            doc /* Process vessel contains fluid with sufficient density to support float. */
        }
        
        assume constraint magneticCouplingMaintained {
            doc /* Magnetic coupling between float and indicators remains effective. */
        }
        
        require accuracyRequirement;
        require visualRequirement;
        require remoteRequirement;
        require safetyRequirement;
    }
}
