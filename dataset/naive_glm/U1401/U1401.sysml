package WaterClockSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Volume :> Real { unit 'm3'; }
    value def FlowRate :> Real { unit 'm3/s'; }
    value def Pressure :> Real { unit 'Pa'; }
    value def Mass :> Real { unit 'kg'; }
    value def Angle :> Real { unit 'rad'; }
    value def AngularVelocity :> Real { unit 'rad/s'; }
    value def Duration :> Real { unit 's'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Count :> Integer;
    value def HourOfDay :> Integer;
    value def SoundLevel :> Real { unit 'dB'; }

    // ===== Item Types =====
    item def Water;
    item def WaterFlow {
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }
    item def HourlySignal;
    item def GongSound {
        attribute level : SoundLevel;
    }
    item def MechanicalMotion {
        attribute angularVelocity : AngularVelocity;
        attribute angle : Angle;
    }

    // ===== Port Definitions =====
    port def WaterOutPort {
        out item water : Water;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }
    port def WaterInPort {
        in item water : Water;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }
    port def SignalOutPort {
        out item signal : HourlySignal;
    }
    port def SignalInPort {
        in item signal : HourlySignal;
    }
    port def MotionOutPort {
        out item motion : MechanicalMotion;
    }
    port def MotionInPort {
        in item motion : MechanicalMotion;
    }
    port def DrainOutPort {
        out item drainedWater : Water;
        attribute flowRate : FlowRate;
    }
    port def DrainInPort {
        in item drainedWater : Water;
        attribute flowRate : FlowRate;
    }
    port def SoundOutPort {
        out item sound : GongSound;
    }

    // ===== Requirements =====
    requirement def TimekeepingRequirement {
        doc "The system shall measure the passage of time using a controlled water flow."
        attribute requiredHourInterval : Duration = 3600 [s];
        constraint { self.hourInterval == requiredHourInterval }
    }

    requirement def ConstantFlowRequirement {
        doc "The float regulator shall maintain a constant outflow rate regardless of supply reservoir level."
        attribute nominalFlowRate : FlowRate = 1.0e-6 [m3/s];
        constraint { self.outflowRate == nominalFlowRate }
    }

    requirement def DisplayRequirement {
        doc "The system shall continuously display the current hour via a dial indicator."
        attribute maxDisplayError : HourOfDay = 1;
    }

    requirement def AutomataRequirement {
        doc "The system shall activate mechanical automata on each hourly signal."
    }

    requirement def AutonomousOperationRequirement {
        doc "The system shall operate autonomously between periodic reservoir refills."
        attribute minOperationDuration : Duration = 86400 [s];
    }

    // ===== Part Definitions =====

    part def SupplyReservoir {
        attribute capacity : Volume = 0.5 [m3];
        attribute currentVolume : Volume;
        attribute currentPressure : Pressure;
        attribute refillThreshold : Volume = 0.05 [m3];

        port waterOut : WaterOutPort;
        port refillPort : WaterInPort;

        exhibit state ReservoirBehavior {
            entry { currentVolume = capacity; currentPressure = 101325 [Pa]; }
            state Adequate {
                entry { waterOut.flowRate = 5.0e-5 [m3/s]; }
                do send Water() to waterOut;
            }
            state Low {
                entry { waterOut.flowRate = 0 [m3/s]; }
            }
            transition Adequate -> Low
                when currentVolume <= refillThreshold;
            transition Low -> Adequate
                when currentVolume > refillThreshold
                accept Water from refillPort;
        }

        requirement satisfaction TimekeepingRequirement::requiredHourInterval;
    }

    part def FloatRegulator {
        attribute nominalFlowRate : FlowRate = 1.0e-6 [m3/s];
        attribute floatPosition : Real;
        attribute valveOpening : Real;
        attribute regulatedPressure : Pressure = 101325 [Pa];

        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;

        exhibit state RegulatorBehavior {
            entry { valveOpening = 1.0; floatPosition = 0.0; }
            state Regulating {
                do {
                    waterOut.flowRate = nominalFlowRate;
                    waterOut.pressure = regulatedPressure;
                    send Water() to waterOut;
                }
            }
            state Blocked {
                entry { waterOut.flowRate = 0 [m3/s]; }
            }
            transition Regulating -> Blocked
                when waterIn.flowRate == 0 [m3/s];
            transition Blocked -> Regulating
                when waterIn.flowRate > 0 [m3/s];
        }

        satisfy ConstantFlowRequirement {
            attribute outflowRate : FlowRate = nominalFlowRate;
        }
    }

    part def TimekeepingChamber {
        attribute chamberVolume : Volume = 3.6e-3 [m3];
        attribute currentFill : Volume;
        attribute fillThreshold : Volume = 3.6e-3 [m3];
        attribute hourInterval : Duration = 3600 [s];
        attribute siphonActive : Boolean = false;
        attribute siphonDrainRate : FlowRate = 1.0e-3 [m3/s];
        attribute cycleCount : Count = 0;

        port waterIn : WaterInPort;
        port signalOut : SignalOutPort;
        port drainOut : DrainOutPort;

        exhibit state ChamberBehavior {
            entry { currentFill = 0 [m3]; }
            state Filling {
                do {
                    currentFill = currentFill + waterIn.flowRate * 1.0 [s];
                }
            }
            state Full {
                entry {
                    cycleCount = cycleCount + 1;
                    send HourlySignal() to signalOut;
                    siphonActive = true;
                }
            }
            state Draining {
                do {
                    drainOut.flowRate = siphonDrainRate;
                    send Water() to drainOut;
                    currentFill = currentFill - siphonDrainRate * 1.0 [s];
                }
            }
            transition Filling -> Full
                when currentFill >= fillThreshold;
            transition Full -> Draining
                when siphonActive;
            transition Draining -> Filling
                when currentFill <= 0 [m3] {
                    siphonActive = false;
                }
        }

        satisfy TimekeepingRequirement {
            attribute hourInterval = self.hourInterval;
        }
    }

    part def GongMechanism {
        attribute strikeCount : Count = 0;
        attribute maxStrikes : Count = 12;
        attribute soundLevel : SoundLevel = 90 [dB];

        port signalIn : SignalInPort;
        port soundOut : SoundOutPort;

        exhibit state GongBehavior {
            state Idle;
            state Striking {
                entry {
                    strikeCount = 0;
                }
                do {
                    strikeCount = strikeCount + 1;
                    send GongSound(level => soundLevel) to soundOut;
                }
            }
            transition Idle -> Striking
                accept HourlySignal from signalIn;
            transition Striking -> Idle
                when strikeCount >= maxStrikes;
        }

        satisfy AutomataRequirement;
    }

    part def SingingBirdAutomaton {
        attribute animationDuration : Duration = 30 [s];
        attribute wingFlapCount : Count = 0;
        attribute songActive : Boolean = false;

        port signalIn : SignalInPort;

        exhibit state BirdBehavior {
            state Idle;
            state Performing {
                entry {
                    wingFlapCount = 0;
                    songActive = true;
                }
                do {
                    wingFlapCount = wingFlapCount + 1;
                }
            }
            state Resting {
                entry { songActive = false; }
            }
            transition Idle -> Performing
                accept HourlySignal from signalIn;
            transition Performing -> Resting
                when wingFlapCount >= 60;
            transition Resting -> Idle
                when true;
        }

        satisfy AutomataRequirement;
    }

    part def ElephantMahoutAutomaton {
        attribute trunkSwingCount : Count = 0;
        attribute mahoutMovementCount : Count = 0;
        attribute performanceDuration : Duration = 45 [s];
        attribute active : Boolean = false;

        port signalIn : SignalInPort;

        exhibit state ElephantBehavior {
            state Idle;
            state Performing {
                entry {
                    trunkSwingCount = 0;
                    mahoutMovementCount = 0;
                    active = true;
                }
                do {
                    trunkSwingCount = trunkSwingCount + 1;
                    mahoutMovementCount = mahoutMovementCount + 1;
                }
            }
            state Resting {
                entry { active = false; }
            }
            transition Idle -> Performing
                accept HourlySignal from signalIn;
            transition Performing -> Resting
                when trunkSwingCount >= 90;
            transition Resting -> Idle
                when true;
        }

        satisfy AutomataRequirement;
    }

    part def DrumMechanism {
        attribute drumRadius : Real = 0.3;
        attribute drumAngle : Angle = 0 [rad];
        attribute drumAngularVelocity : AngularVelocity = 0 [rad/s];
        attribute totalRotation : Angle = 0 [rad];
        attribute hoursPerRevolution : Count = 12;
        attribute rotationPerHour : Angle = 0.5236 [rad];

        port drainIn : DrainInPort;
        port motionOut : MotionOutPort;

        exhibit state DrumBehavior {
            state Rotating {
                do {
                    drumAngularVelocity = 0.0001454 [rad/s];
                    drumAngle = drumAngle + drumAngularVelocity * 1.0 [s];
                    totalRotation = totalRotation + drumAngularVelocity * 1.0 [s];
                    motionOut.motion.angularVelocity = drumAngularVelocity;
                    motionOut.motion.angle = drumAngle;
                    send MechanicalMotion(angularVelocity => drumAngularVelocity, angle => drumAngle) to motionOut;
                }
            }
            state Stopped {
                entry { drumAngularVelocity = 0 [rad/s]; }
            }
            transition Rotating -> Stopped
                when drainIn.flowRate == 0 [m3/s];
            transition Stopped -> Rotating
                when drainIn.flowRate > 0 [m3/s];
        }
    }

    part def DialIndicator {
        attribute currentHour : HourOfDay = 0;
        attribute pointerAngle : Angle = 0 [rad];
        attribute anglePerHour : Angle = 0.5236 [rad];
        attribute totalHoursElapsed : Count = 0;

        port motionIn : MotionInPort;

        exhibit state DialBehavior {
            state Displaying {
                do {
                    pointerAngle = motionIn.motion.angle;
                    currentHour = (totalHoursElapsed mod 12) + 1;
                }
            }
            transition Displaying -> Displaying
                when pointerAngle >= totalHoursElapsed * anglePerHour {
                    totalHoursElapsed = totalHoursElapsed + 1;
                }
        }

        satisfy DisplayRequirement {
            attribute displayError : HourOfDay = 0;
        }
    }

    part def WaterClock {
        attribute systemStartTime : Duration;
        attribute totalCycles : Count = 0;
        attribute operational : Boolean = true;

        port refillPort : WaterInPort;
        port soundPort : SoundOutPort;

        part supplyReservoir : SupplyReservoir {
            attribute capacity : Volume = 0.5 [m3];
        }
        part floatRegulator : FloatRegulator {
            attribute nominalFlowRate : FlowRate = 1.0e-6 [m3/s];
        }
        part timekeepingChamber : TimekeepingChamber {
            attribute chamberVolume : Volume = 3.6e-3 [m3];
        }
        part gongMechanism : GongMechanism {
            attribute maxStrikes : Count = 12;
        }
        part singingBird : SingingBirdAutomaton {
            attribute animationDuration : Duration = 30 [s];
        }
        part elephantMahout : ElephantMahoutAutomaton {
            attribute performanceDuration : Duration = 45 [s];
        }
        part drumMechanism : DrumMechanism {
            attribute drumRadius : Real = 0.3;
        }
        part dialIndicator : DialIndicator {
            attribute anglePerHour : Angle = 0.5236 [rad];
        }

        // ===== Connections =====
        connection waterSupplyToRegulator : WaterFlow
            connect supplyReservoir.waterOut to floatRegulator.waterIn;

        connection regulatedFlowToChamber : WaterFlow
            connect floatRegulator.waterOut to timekeepingChamber.waterIn;

        connection hourlySignalToGong : HourlySignal
            connect timekeepingChamber.signalOut to gongMechanism.signalIn;

        connection hourlySignalToBird : HourlySignal
            connect timekeepingChamber.signalOut to singingBird.signalIn;

        connection hourlySignalToElephant : HourlySignal
            connect timekeepingChamber.signalOut to elephantMahout.signalIn;

        connection drainToDrum : WaterFlow
            connect timekeepingChamber.drainOut to drumMechanism.drainIn;

        connection drumMotionToDial : MechanicalMotion
            connect drumMechanism.motionOut to dialIndicator.motionIn;

        connection refillPath : WaterFlow
            connect refillPort to supplyReservoir.refillPort;

        connection gongSoundPath : GongSound
            connect gongMechanism.soundOut to soundPort;

        exhibit state SystemBehavior {
            entry {
                systemStartTime = 0 [s];
                totalCycles = 0;
                operational = true;
            }
            state Operating {
                do {
                    totalCycles = timekeepingChamber.cycleCount;
                }
            }
            state RefillNeeded {
                entry { operational = false; }
            }
            state Refilled {
                entry { operational = true; }
            }
            transition Operating -> RefillNeeded
                when supplyReservoir.currentVolume <= supplyReservoir.refillThreshold;
            transition RefillNeeded -> Refilled
                accept Water from refillPort;
            transition Refilled -> Operating
                when supplyReservoir.currentVolume > supplyReservoir.refillThreshold;
        }

        satisfy AutonomousOperationRequirement {
            attribute operationDuration : Duration = totalCycles * 3600 [s];
        }
    }
}
