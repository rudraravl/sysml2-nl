package WangensteenSuctionSystem {

    import ScalarValues::*;

    unit Pa :> One;
    unit mL :> One;
    unit mL_per_min :> One;
    unit s :> One;
    unit cm :> One;
    unit mm :> One;

    value type Pressure :> Real { unit Pa; }
    value type Volume :> Real { unit mL; }
    value type FlowRate :> Real { unit mL_per_min; }
    value type Duration :> Real { unit s; }
    value type Length :> Real { unit cm; }

    item def GastricFluid;
    item def Air;
    item def Water;

    enum def OperatingMode {
        literal continuous;
        literal intermittent;
    }

    enum def SystemMode {
        literal off;
        literal priming;
        literal operating;
        literal alarm;
    }

    requirement def SafeSuctionPressure {
        subject suctionPressure : Pressure;
        constraint { suctionPressure >= 0 [Pa] and suctionPressure <= 12000 [Pa]; }
    }

    requirement def DrainageEffectiveness {
        subject drainageFlow : FlowRate;
        constraint { drainageFlow >= 10 [mL_per_min] and drainageFlow <= 200 [mL_per_min]; }
    }

    requirement def SafetyValveResponse {
        subject triggerPressure : Pressure;
        constraint { triggerPressure > 12000 [Pa]; }
    }

    requirement def CollectionCapacity {
        subject bottleVolume : Volume;
        constraint { bottleVolume <= 2000 [mL]; }
    }

    requirement def ModeSelection {
        subject selectedMode : OperatingMode;
        constraint { selectedMode == OperatingMode::continuous or selectedMode == OperatingMode::intermittent; }
    }

    port def FluidPort {
        in item fluid : GastricFluid;
        in item air : Air;
    }

    port def PressurePort {
        out attribute pressure : Pressure;
    }

    port def VolumePort {
        out attribute volume : Volume;
    }

    port def ControlPort {
        in attribute setPressure : Pressure;
        in attribute mode : OperatingMode;
        out attribute measuredPressure : Pressure;
        out attribute status : SystemMode;
    }

    part def NasogastricTube {
        attribute length : Length = 120 [cm];
        attribute innerDiameter : Real = 5 [mm];
        port patientEnd : FluidPort;
        port distalEnd : FluidPort;
    }

    part def CollectionBottle {
        attribute capacity : Volume = 2000 [mL];
        attribute currentVolume : Volume = 0 [mL];
        port inlet : FluidPort;
        port outlet : FluidPort;
        port levelOutput : VolumePort;

        action def MeasureVolume {
            in current : Volume;
            out reading : Volume;
        }

        perform measureVolume : MeasureVolume {
            in current = currentVolume;
            out reading = levelOutput.volume;
        }
    }

    part def WaterSealChamber {
        attribute waterColumnHeight : Real = 5 [cm];
        attribute waterLevel : Volume = 50 [mL];
        attribute sealed : Boolean = true;
        port inlet : FluidPort;
        port outlet : FluidPort;

        action def PermitOneWayFlow {
            in item incomingFluid : GastricFluid;
            in item incomingAir : Air;
            out item outgoingFluid : GastricFluid;
            out item outgoingAir : Air;
        }

        perform permitFlow : PermitOneWayFlow;
    }

    part def VacuumPump {
        attribute maxVacuum : Pressure = 20000 [Pa];
        attribute currentVacuum : Pressure = 0 [Pa];
        port inlet : FluidPort;
        port vacuumOutput : PressurePort;
        port powerControl : ControlPort;

        action def GenerateVacuum {
            in target : Pressure;
            out generated : Pressure;
        }

        perform generateVacuum : GenerateVacuum {
            in target = powerControl.setPressure;
            out generated = vacuumOutput.pressure;
        }
    }

    part def SuctionRegulator {
        attribute targetPressure : Pressure = 8000 [Pa];
        attribute regulatedPressure : Pressure = 0 [Pa];
        port inlet : FluidPort;
        port outlet : FluidPort;
        port pressureOutput : PressurePort;
        port control : ControlPort;

        action def Regulate {
            in target : Pressure;
            in current : Pressure;
            out regulated : Pressure;
        }

        perform regulate : Regulate {
            in target = control.setPressure;
            in current = pressureOutput.pressure;
            out regulated = regulatedPressure;
        }
    }

    part def PressureGauge {
        attribute displayedPressure : Pressure = 0 [Pa];
        port sensingInput : PressurePort;
        port displayOutput : ControlPort;

        action def DisplayPressure {
            in sensed : Pressure;
            out shown : Pressure;
        }

        perform displayPressure : DisplayPressure {
            in sensed = sensingInput.pressure;
            out shown = displayedPressure;
        }
    }

    part def SafetyValve {
        attribute threshold : Pressure = 12000 [Pa];
        attribute isOpen : Boolean = false;
        port sensingInput : PressurePort;
        port vent : FluidPort;

        action def MonitorPressure {
            in sensed : Pressure;
            out release : Boolean;
        }

        perform monitorPressure : MonitorPressure {
            in sensed = sensingInput.pressure;
            out release = isOpen;
        }
    }

    part def ControlUnit {
        attribute desiredPressure : Pressure = 8000 [Pa];
        attribute operatingMode : OperatingMode = OperatingMode::continuous;
        attribute cycleOnTime : Duration = 60 [s];
        attribute cycleOffTime : Duration = 30 [s];
        attribute systemStatus : SystemMode = SystemMode::off;

        port operatorInterface : ControlPort;
        port pumpControl : ControlPort;
        port regulatorControl : ControlPort;
        port gaugeReadout : ControlPort;
        port safetyMonitor : ControlPort;
        port bottleMonitor : VolumePort;

        action def CycleIntermittent {
            in onTime : Duration;
            in offTime : Duration;
            out active : Boolean;
        }

        perform cycleIntermittent : CycleIntermittent {
            in onTime = cycleOnTime;
            in offTime = cycleOffTime;
        }
    }

    part def WangensteenSuctionSystem {

        part tube : NasogastricTube;
        part bottle : CollectionBottle;
        part seal : WaterSealChamber;
        part pump : VacuumPump;
        part regulator : SuctionRegulator;
        part gauge : PressureGauge;
        part safetyValve : SafetyValve;
        part controller : ControlUnit;

        connect tube.distalEnd to bottle.inlet;
        connect bottle.outlet to seal.inlet;
        connect seal.outlet to regulator.inlet;
        connect regulator.outlet to pump.inlet;

        connect regulator.pressureOutput to gauge.sensingInput;
        connect regulator.pressureOutput to safetyValve.sensingInput;
        connect pump.vacuumOutput to regulator.pressureOutput;

        connect controller.pumpControl to pump.powerControl;
        connect controller.regulatorControl to regulator.control;
        connect controller.gaugeReadout to gauge.displayOutput;
        connect controller.bottleMonitor to bottle.levelOutput;

        flow of GastricFluid from tube.patientEnd to bottle.inlet;
        flow of Air from seal.outlet to pump.inlet;

        requirement safePressureReq : SafeSuctionPressure {
            subject suctionPressure = regulator.regulatedPressure;
        }

        requirement drainageReq : DrainageEffectiveness {
            subject drainageFlow = FlowRate(0);
        }

        requirement safetyValveReq : SafetyValveResponse {
            subject triggerPressure = safetyValve.threshold;
        }

        requirement capacityReq : CollectionCapacity {
            subject bottleVolume = bottle.capacity;
        }

        requirement modeReq : ModeSelection {
            subject selectedMode = controller.operatingMode;
        }

        satisfy safePressureReq by regulator;
        satisfy drainageReq by tube;
        satisfy safetyValveReq by safetyValve;
        satisfy capacityReq by bottle;
        satisfy modeReq by controller;

        state def SystemBehavior {

            attribute mode : SystemMode = SystemMode::off;

            state off {
                entry { mode = SystemMode::off; }
            }

            state priming {
                entry { mode = SystemMode::priming; }
                do {
                    controller.desiredPressure = 2000 [Pa];
                    pump.currentVacuum = 2000 [Pa];
                }
            }

            state operating {
                entry { mode = SystemMode::operating; }

                state continuousMode {
                    entry { controller.operatingMode = OperatingMode::continuous; }
                }

                state intermittentMode {
                    entry { controller.operatingMode = OperatingMode::intermittent; }
                }

                transition continuousMode to intermittentMode
                    when controller.operatingMode == OperatingMode::intermittent;

                transition intermittentMode to continuousMode
                    when controller.operatingMode == OperatingMode::continuous;
            }

            state alarm {
                entry { mode = SystemMode::alarm; }
                do {
                    pump.currentVacuum = 0 [Pa];
                    safetyValve.isOpen = true;
                }
            }

            transition off to priming
                when controller.operatorInterface.mode != SystemMode::off;

            transition priming to operating
                when seal.waterLevel >= 50 [mL] and pump.currentVacuum >= 2000 [Pa];

            transition operating to alarm
                when bottle.currentVolume >= bottle.capacity
                    or gauge.displayedPressure > 12000 [Pa]
                    or gauge.displayedPressure < 0 [Pa];

            transition alarm to operating
                when bottle.currentVolume < bottle.capacity
                    and gauge.displayedPressure <= 12000 [Pa]
                    and gauge.displayedPressure >= 0 [Pa]
                    and safetyValve.isOpen == false;

            transition operating to off
                when controller.operatorInterface.mode == SystemMode::off;

            transition alarm to off
                when controller.operatorInterface.mode == SystemMode::off;
        }

        state systemState : SystemBehavior;
    }
}
