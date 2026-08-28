package AutomatedUrineCollectionDevice {
    import SI::*
    import ScalarValues::*

    // ---------- Value Types ----------
    def VolumeUnit :> Unit {
        * magnitude = 1e-3;
        * unit = "mL";
    }
    value type Volume :> Real { unit VolumeUnit; }

    def PressureUnit :> Unit {
        * magnitude = 1e3;
        * unit = "Pa";
    }
    value type Pressure :> Real { unit PressureUnit; }

    value type Temperature :> Real { unit "K"; }
    value type Dimensionless :> Real { }

    // ---------- Item Types ----------
    item def Urine {
        attribute density : Volume = 1.0 [mL];
        attribute ph : Real;
    }

    item def ControlSignal {
        attribute id : String;
        attribute priority : Integer;
    }

    item def SensorReading {
        attribute timestamp : Time;
        attribute value : Real;
    }

    item def VolumeReading :> SensorReading {
        redefines value : Volume;
    }

    item def PressureReading :> SensorReading {
        redefines value : Pressure;
    }

    item def AlarmSignal :> ControlSignal {
        attribute severity : Integer;
    }

    // ---------- Interfaces / Ports ----------
    port def FluidPort {
        out item urine : Urine;
    }

    port def SensorPort {
        out item reading : SensorReading;
    }

    port def ControlPort {
        out item signal : ControlSignal;
        in item ack : ControlSignal;
    }

    port def PowerPort {
        attribute voltage : Real;
        in attribute current : Real;
    }

    // ---------- Requirements ----------
    requirement def ReservoirCapacityRequirement {
        doc <<The collection reservoir shall hold up to 500 mL of fluid.>>
        constraint { reservoirCapacity <= 500 [mL] }
        attribute reservoirCapacity : Volume = 500 [mL];
    }

    requirement def PressureSafetyRequirement {
        doc <<The internal pressure shall remain within safe limits.>>
        constraint { internalPressure <= maxSafePressure }
        attribute maxSafePressure : Pressure = 5.0 [Pa];
        attribute internalPressure : Pressure;
    }

    requirement def OverflowProtectionRequirement {
        doc <<Overflow protection shall activate if internal pressure exceeds a critical threshold.>>
        constraint { criticalPressureThreshold = 7.0 [Pa] }
        attribute criticalPressureThreshold : Pressure;
    }

    requirement def AutomatedSealingRequirement {
        doc <<The sealing assembly shall seal the reservoir once collection is complete or when manually triggered.>>
    }

    requirement def HygieneRequirement {
        doc <<All fluid-contacting components shall be medical-grade polymer and disposable.>>
    }

    // ---------- Parts ----------
    part def CollectionReservoir {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute material : String = "Medical-grade polymer";
        attribute capacity : Volume = 500 [mL];
        attribute currentVolume : Volume = 0 [mL];
        attribute internalPressure : Pressure = 0 [Pa];
        attribute isSealed : Boolean = false;

        requirement reservoirCapacityRequirement : ReservoirCapacityRequirement;
        requirement hygieneRequirement : HygieneRequirement;

        action fill {
            in urine : Urine;
            then updateVolume;
        }
        action updateVolume {
            out newVolume : Volume;
        }
        action drain {
            out urine : Urine;
        }
    }

    part def VolumeMonitor {
        port sensorOut : SensorPort;
        port power : PowerPort;
        attribute samplingRate : Real = 10.0;
        attribute measurementRange : Volume = 500 [mL];
        attribute accuracy : Volume = 1.0 [mL];

        action measureVolume {
            in reservoirVolume : Volume;
            out reading : VolumeReading;
        }
    }

    part def PressureMonitor {
        port sensorOut : SensorPort;
        port power : PowerPort;
        attribute samplingRate : Real = 20.0;
        attribute measurementRange : Pressure = 10.0 [Pa];
        attribute accuracy : Pressure = 0.1 [Pa];

        action measurePressure {
            in reservoirPressure : Pressure;
            out reading : PressureReading;
        }
    }

    part def OverflowProtectionSystem {
        port controlIn : ControlPort;
        port alarmOut : ControlPort;
        attribute criticalThreshold : Pressure = 7.0 [Pa];
        attribute isActive : Boolean = false;

        requirement overflowProtectionRequirement : OverflowProtectionRequirement;

        action evaluatePressure {
            in pressureReading : PressureReading;
            out alarm : AlarmSignal;
        }
        action activateRelief {
            out signal : ControlSignal;
        }
    }

    part def SealingAssembly {
        port controlIn : ControlPort;
        port power : PowerPort;
        attribute sealType : String = "Hygienic heat seal";
        attribute sealTime : Time = 2.0;
        attribute isSealed : Boolean = false;

        requirement automatedSealingRequirement : AutomatedSealingRequirement;

        action seal {
            in trigger : ControlSignal;
            out sealComplete : ControlSignal;
        }
    }

    part def CentralControlModule {
        port volumeSensorIn : SensorPort;
        port pressureSensorIn : SensorPort;
        port overflowControl : ControlPort;
        port sealingControl : ControlPort;
        port power : PowerPort;
        attribute processorType : String = "ARM Cortex-M4";
        attribute clockSpeed : Real = 168e6;
        attribute firmwareVersion : String = "1.0.0";
        attribute targetVolume : Volume = 450 [mL];
        attribute nearFullThreshold : Volume = 400 [mL];
        attribute maxSafePressure : Pressure = 5.0 [Pa];

        requirement pressureSafetyRequirement : PressureSafetyRequirement;

        action processSensorData {
            in volumeReading : VolumeReading;
            in pressureReading : PressureReading;
            out decision : ControlSignal;
        }
        action evaluateThresholds {
            in currentVolume : Volume;
            in currentPressure : Pressure;
            out command : ControlSignal;
        }
        action issueSealCommand {
            out sealCommand : ControlSignal;
        }
        action issueAlarmCommand {
            out alarmCommand : AlarmSignal;
        }
    }

    part def PowerSupply {
        port powerOut : PowerPort;
        attribute type : String = "Rechargeable Li-ion";
        attribute voltage : Real = 3.7;
        attribute capacity_mAh : Real = 1200.0;
        attribute chargeLevel : Real = 100.0;

        action supplyPower {
            out voltage : Real;
        }
    }

    part def UserInterface {
        port controlOut : ControlPort;
        attribute hasManualSealButton : Boolean = true;
        attribute hasStatusIndicator : Boolean = true;

        action displayStatus {
            in status : String;
        }
        action manualSealTrigger {
            out signal : ControlSignal;
        }
    }

    // ---------- Top-level System ----------
    part def AutomatedUrineCollectionSystem {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port uiPort : ControlPort;

        part reservoir : CollectionReservoir {
            redefines capacity = 500 [mL];
        }
        part volumeMonitor : VolumeMonitor;
        part pressureMonitor : PressureMonitor;
        part overflowProtection : OverflowProtectionSystem;
        part controlModule : CentralControlModule;
        part sealingAssembly : SealingAssembly;
        part powerSupply : PowerSupply;
        part userInterface : UserInterface;

        // Connections
        connection fluidInlet : FluidPort connect inlet to reservoir.fluidIn;
        connection fluidOutlet : FluidPort connect reservoir.fluidOut to outlet;

        connection volumeData : SensorPort connect volumeMonitor.sensorOut to controlModule.volumeSensorIn;
        connection pressureData : SensorPort connect pressureMonitor.sensorOut to controlModule.pressureSensorIn;

        connection overflowCommand : ControlPort connect controlModule.overflowControl to overflowProtection.controlIn;
        connection overflowAlarm : ControlPort connect overflowProtection.alarmOut to controlModule.overflowControl;

        connection sealCommand : ControlPort connect controlModule.sealingControl to sealingAssembly.controlIn;

        connection uiCommand : ControlPort connect userInterface.controlOut to controlModule.overflowControl;

        connection powerToVolume : PowerPort connect powerSupply.powerOut to volumeMonitor.power;
        connection powerToPressure : PowerPort connect powerSupply.powerOut to pressureMonitor.power;
        connection powerToControl : PowerPort connect powerSupply.powerOut to controlModule.power;
        connection powerToSealing : PowerPort connect powerSupply.powerOut to sealingAssembly.power;

        // ---------- State Machine ----------
        state def CollectionLifecycle {
            attribute currentVolume : Volume;
            attribute currentPressure : Pressure;

            state standby {
                entry action { /* ready for use */ }
                on volumeMonitor.measureVolume.reading.value > 0 [mL] transition to active;
            }

            state active {
                entry action { controlModule.processSensorData(); }
                on currentVolume >= 400 [mL] transition to nearFull;
                on currentPressure > 5.0 [Pa] transition to overflowProtection;
            }

            state nearFull {
                entry action { userInterface.displayStatus("Near Full"); }
                on currentVolume >= 450 [mL] transition to full;
                on currentPressure > 5.0 [Pa] transition to overflowProtection;
            }

            state full {
                entry action { controlModule.issueSealCommand(); }
                transition to sealing;
            }

            state overflowProtection {
                entry action { overflowProtection.activateRelief(); controlModule.issueAlarmCommand(); }
                transition to sealing;
            }

            state sealing {
                entry action { sealingAssembly.seal(); }
                on sealingAssembly.isSealed == true transition to sealed;
            }

            state sealed {
                entry action { userInterface.displayStatus("Sealed - Ready for Removal"); }
                on userInterface.manualSealTrigger.signal.id == "RESET" transition to standby;
            }
        }

        behavior lifecycle : CollectionLifecycle;

        // ---------- Requirements at system level ----------
        requirement systemReservoirCapacity : ReservoirCapacityRequirement {
            redefines reservoirCapacity = 500 [mL];
        }
        requirement systemPressureSafety : PressureSafetyRequirement {
            redefines maxSafePressure = 5.0 [Pa];
        }
        requirement systemOverflowProtection : OverflowProtectionRequirement {
            redefines criticalPressureThreshold = 7.0 [Pa];
        }
        requirement systemAutomatedSealing : AutomatedSealingRequirement;
        requirement systemHygiene : HygieneRequirement;
    }
}
