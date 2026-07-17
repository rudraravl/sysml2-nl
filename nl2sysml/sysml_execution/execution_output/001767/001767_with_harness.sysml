package 'Hill Water Clock System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    doc /*
     * This model describes a monumental water clock system based on the historical 
     * designs documented by Donald Routledge Hill, particularly the Islamic water 
     * clocks of Al-Jazari. The system's primary function is to automatically measure 
     * and display the passage of time through a precisely regulated flow of water 
     * that drives mechanical automata and visual time indicators.
     */

    attribute def ClockSignal;
    attribute def StartOperation;
    attribute def StopOperation;

    attribute def WaterVolume :> Real;
    attribute def WaterFlowRate :> Real;
    attribute def AngularPosition :> Real;
    attribute def TimeInterval :> Real;

    item def Water {
        attribute volume : WaterVolume;
    }

    item def MechanicalForce {
        attribute torque : ISQ::TorqueValue;
    }

    port def WaterInletPort {
        in item waterFlow : Water;
    }

    port def WaterOutletPort {
        out item waterFlow : Water;
    }

    port def MechanicalDrivePort {
        out item force : MechanicalForce;
    }

    port def SignalPort {
        out signal : ClockSignal;
    }

    part def SupplyReservoir {
        doc /* Upper reservoir maintaining constant head pressure */
        
        attribute capacity : WaterVolume;
        attribute currentLevel : WaterVolume;
        attribute headHeight : ISQ::LengthValue;
        
        port outlet : WaterOutletPort;
        port refillInlet : WaterInletPort;
        
        action maintainLevel {
            in refillRate : WaterFlowRate;
            in outflowRate : WaterFlowRate;
            inout level : WaterVolume;
        }
    }

    part def FloatRegulator {
        doc /* Float valve mechanism ensuring constant flow rate */
        
        attribute floatDiameter : ISQ::LengthValue;
        attribute valveOpening : Real;
        attribute targetFlowRate : WaterFlowRate;
        
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        
        action regulateFlow {
            in incomingPressure : ISQ::PressureValue;
            in floatPosition : ISQ::LengthValue;
            out regulatedFlow : WaterFlowRate;
        }
        
        perform action continuousRegulation references regulateFlow;
    }

    part def TimekeepingChamber {
        doc /* Calibrated vessel that fills at known rate to measure time intervals */
        
        attribute chamberVolume : WaterVolume;
        attribute fillDuration : TimeInterval;
        attribute siphonThreshold : WaterVolume;
        
        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        port triggerOutput : SignalPort;
        
        action measureInterval {
            in flowRate : WaterFlowRate;
            inout currentVolume : WaterVolume;
            out intervalComplete : ClockSignal;
        }
        
        action siphonDrain {
            inout chamberLevel : WaterVolume;
        }
    }

    part def DrumMechanism {
        doc /* Rotating drum driven by water flow, marked with time divisions */
        
        attribute drumRadius : ISQ::LengthValue;
        attribute numberOfDivisions : Integer;
        attribute currentRotation : AngularPosition;
        
        port waterDrive : WaterInletPort;
        port mechanicalOutput : MechanicalDrivePort;
        
        action rotateDrum {
            in waterForce : ISQ::ForceValue;
            in currentAngle : AngularPosition;
            out newAngle : AngularPosition;
            out driveTorque : ISQ::TorqueValue;
        }
    }

    part def AutomatonFigure {
        doc /* Mechanical figure performing actions at specified time intervals */
        
        attribute figureType : String;
        attribute actionSequence : Integer;
        
        port driveInput : MechanicalDrivePort;
        port triggerInput : SignalPort;
        
        action performAction {
            in trigger : ClockSignal;
            in drivingForce : MechanicalForce;
        }
    }

    part def DialIndicator {
        doc /* Visual display showing current hour and time divisions */
        
        attribute numberOfHours : Integer;
        attribute pointerAngle : AngularPosition;
        
        port driveInput : MechanicalDrivePort;
        
        action updateDisplay {
            in mechanicalInput : MechanicalForce;
            inout displayAngle : AngularPosition;
        }
    }

    part def GongMechanism {
        doc /* Striking mechanism activated at hour intervals */
        
        attribute numberOfStrikes : Integer;
        
        port triggerInput : SignalPort;
        
        action strikeGong {
            in trigger : ClockSignal;
            in strikeCount : Integer;
        }
    }

    requirement def TimekeepingRequirement {
        doc /* Requirements for accurate time measurement */
        
        subject clock : MonumentalWaterClock;
    }

    requirement <'HILL-REQ-001'> accurateTimeMeasurement : TimekeepingRequirement {
        doc /* 
         * The water clock shall measure time intervals with accuracy 
         * within ±2 minutes per 24-hour period under stable conditions 
         */
        
        assume constraint stableWaterSupply {
            doc /* Water supply pressure remains constant */
        }
        
        require constraint flowRateStability {
            doc /* Regulated flow rate varies by no more than 1% */
        }
    }

    requirement <'HILL-REQ-002'> automaticOperation : TimekeepingRequirement {
        doc /* 
         * The system shall operate continuously and autonomously 
         * once started, requiring only periodic water replenishment 
         */
        
        require constraint continuousFlow {
            doc /* Water flow maintains uninterrupted operation */
        }
        
        require constraint automaticReset {
            doc /* Timekeeping chambers reset automatically via siphon */
        }
    }

    requirement <'HILL-REQ-003'> visualAndAuditoryDisplay : TimekeepingRequirement {
        doc /* 
         * The clock shall provide both visual time indication 
         * and auditory signals at regular intervals 
         */
        
        require constraint dialDisplay {
            doc /* Dial continuously shows current time position */
        }
        
        require constraint hourlySignal {
            doc /* Gong strikes at completion of each hour */
        }
        
        require constraint automataAnimation {
            doc /* Mechanical figures perform actions at specified times */
        }
    }

    action def OperateWaterClock {
        doc /* Complete operational cycle of the water clock system */
        
        in startSignal : StartOperation;
        in stopSignal : StopOperation;
        in supplyFlowRate : WaterFlowRate;
        out timeDisplaySequence : AngularPosition[*];
        out hourSignals : ClockSignal[*];
        
        private attribute displayAngles := ( );
        private attribute signals := ( );
        private attribute currentAngle : AngularPosition;
    }

    part def MonumentalWaterClock {
        doc /* 
         * Complete water clock system implementing Hill's documented design 
         * principles for Islamic monumental water clocks, providing continuous 
         * automatic timekeeping with mechanical automata displays 
         */
        
        attribute operatingDuration : TimeInterval;
        attribute calibrationAccuracy : Real;
        
        part upperReservoir : SupplyReservoir {
            attribute capacity = 500.0;
            attribute headHeight = 3.0;
        }
        
        part flowRegulator : FloatRegulator {
            attribute targetFlowRate = 10.0;
            attribute floatDiameter = 0.15;
        }
        
        part hourChamber : TimekeepingChamber {
            attribute chamberVolume = 10.0;
            attribute fillDuration = 3600.0;
        }
        
        part timeDrum : DrumMechanism {
            attribute drumRadius = 0.5;
            attribute numberOfDivisions = 24;
        }
        
        part hourDial : DialIndicator {
            attribute numberOfHours = 12;
        }
        
        part birdAutomaton : AutomatonFigure {
            attribute figureType = "singing bird";
        }
        
        part elephantAutomaton : AutomatonFigure {
            attribute figureType = "elephant with mahout";
        }
        
        part hourGong : GongMechanism {
            attribute numberOfStrikes = 12;
        }
        
        connection reservoirToRegulator : WaterConnection
            connect upperReservoir.outlet to flowRegulator.inlet;
        
        connection regulatorToChamber : WaterConnection
            connect flowRegulator.outlet to hourChamber.waterInlet;
        
        connection chamberToDrum : WaterConnection
            connect hourChamber.waterOutlet to timeDrum.waterDrive;
        
        connection drumToDial : MechanicalConnection
            connect timeDrum.mechanicalOutput to hourDial.driveInput;
        
        connection chamberTriggerToBird : SignalConnection
            connect hourChamber.triggerOutput to birdAutomaton.triggerInput;
        
        connection chamberTriggerToElephant : SignalConnection
            connect hourChamber.triggerOutput to elephantAutomaton.triggerInput;
        
        connection chamberTriggerToGong : SignalConnection
            connect hourChamber.triggerOutput to hourGong.triggerInput;
        
        perform action operateClock : OperateWaterClock {
            first start;
            
            then action initializeSystem {
                action fillUpperReservoir {
                    in refillRate : WaterFlowRate;
                }
                then action calibrateFloatValve {
                    in targetRate : WaterFlowRate;
                }
                then action setDrumPosition {
                    in initialAngle : AngularPosition;
                }
            }
            
            then merge continuousOperation;
            
            then action timekeepingCycle {
                action regulateWaterFlow {
                    in pressure : ISQ::PressureValue;
                    out steadyFlow : WaterFlowRate;
                }
                
                flow regulateWaterFlow.steadyFlow to fillChamber.flowRate;
                
                action fillChamber {
                    in flowRate : WaterFlowRate;
                    inout volume : WaterVolume;
                    out chamberFullSignal : ClockSignal;
                }
                
                flow fillChamber.chamberFullSignal to driveRotation.trigger;
                
                action driveRotation {
                    in trigger : ClockSignal;
                    in waterForce : ISQ::ForceValue;
                    out drumTorque : ISQ::TorqueValue;
                }
                
                flow driveRotation.drumTorque to updateDial.mechanicalInput;
                
                action updateDial {
                    in mechanicalInput : ISQ::TorqueValue;
                    inout angle : AngularPosition;
                }
            }
            
            then decide;
                if hourComplete then activateDisplays;
                if hourIncomplete then continuousOperation;
            
            action activateDisplays {
                action drainViaSiphon {
                    inout chamberLevel : WaterVolume;
                }
                
                and {
                    action animateBird {
                        in trigger : ClockSignal;
                    }
                    action animateElephant {
                        in trigger : ClockSignal;
                    }
                    action strikeHours {
                        in trigger : ClockSignal;
                        in count : Integer;
                    }
                }
            }
            
            then continuousOperation;
            
            accept stopSignal : StopOperation;
            then done;
        }
        
        satisfy accurateTimeMeasurement;
        satisfy automaticOperation;
        satisfy visualAndAuditoryDisplay;
    }
    
    binding def WaterConnection {
        end source : WaterOutletPort;
        end target : WaterInletPort;
    }
    
    binding def MechanicalConnection {
        end source : MechanicalDrivePort;
        end target : MechanicalDrivePort;
    }
    
    binding def SignalConnection {
        end source : SignalPort;
        end target : SignalPort;
    }

    part monumentalWaterClock : MonumentalWaterClock;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Hill Water Clock System'::*;

    action orchestrator {
        attribute testStartSignal : StartOperation;
        attribute testStopSignal : StopOperation;
        attribute testSupplyFlowRate : WaterFlowRate = 0.0;
        action actionProbe : OperateWaterClock {
            in startSignal = testStartSignal;
            in stopSignal = testStopSignal;
            in supplyFlowRate = testSupplyFlowRate;
        }
        first actionProbe;
    }
}
