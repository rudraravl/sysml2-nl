package ArtificialUrinarySphincter {
    import ISQ::*;
    import SI::*;

    attribute def PressureValue :> Real { unit: 'Pa'; }
    attribute def VolumeValue :> Real { unit: 'L'; }
    attribute def TimeValue :> Real { unit: 's'; }

    item def Saline;

    port def FluidPort {
        in out item saline: Saline;
        attribute pressure: PressureValue;
    }

    port def DigitalSignalPort {
        in out attribute active: Boolean;
    }

    part def InflatableCuff {
        port fluidPort: FluidPort;
        attribute currentVolume: VolumeValue;
        attribute targetPressure: PressureValue;
    }

    part def FluidReservoir {
        port fluidPort: FluidPort;
        attribute currentVolume: VolumeValue;
    }

    part def ControlPump {
        port reservoirPort: FluidPort;
        port cuffPort: FluidPort;
        port controlPort: DigitalSignalPort;
    }

    part def ReleaseValve {
        port cuffPort: FluidPort;
        port reservoirPort: FluidPort;
        port controlPort: DigitalSignalPort;
    }

    part def PressureSensor {
        port cuffPort: FluidPort;
        port signalPort: DigitalSignalPort;
        attribute threshold: PressureValue;
    }

    part def ActivationButton {
        port signalPort: DigitalSignalPort;
    }

    part def ControlModule {
        port buttonPort: DigitalSignalPort;
        port pressurePort: DigitalSignalPort;
        port pumpPort: DigitalSignalPort;
        port valvePort: DigitalSignalPort;
        
        attribute voidingDuration: TimeValue = 120.0;
        attribute safePressure: PressureValue = 6000.0;

        state machine behavior: ControlBehavior {
            state Inflating {
                entry: pumpPort.active = true;
            }
            state Closed {
                entry: pumpPort.active = false;
            }
            state Voiding {
                entry: valvePort.active = true;
                exit: valvePort.active = false;
            }
            transition from Inflating to Closed
                when pressurePort.active == true;
            transition from Closed to Voiding
                when buttonPort.active == true;
            transition from Voiding to Inflating
                after voidingDuration;
        }
    }

    part def AUS {
        part cuff: InflatableCuff;
        part reservoir: FluidReservoir;
        part pump: ControlPump;
        part valve: ReleaseValve;
        part sensor: PressureSensor;
        part button: ActivationButton;
        part controller: ControlModule;

        connect reservoir.fluidPort to pump.reservoirPort;
        connect pump.cuffPort to cuff.fluidPort;
        connect cuff.fluidPort to valve.cuffPort;
        connect valve.reservoirPort to reservoir.fluidPort;
        
        connect cuff.fluidPort to sensor.cuffPort;
        connect sensor.signalPort to controller.pressurePort;
        
        connect button.signalPort to controller.buttonPort;
        
        connect controller.pumpPort to pump.controlPort;
        connect controller.valvePort to valve.controlPort;
    }

    requirement def ContinenceRequirement {
        subject cuff: InflatableCuff;
        requirement: The cuff shall maintain urethral closure when inflated to the target pressure.
    }

    requirement def VoidingRequirement {
        subject valve: ReleaseValve;
        requirement: The valve shall open upon button activation to allow voiding for a pre-set duration.
    }

    requirement def SafetyRequirement {
        subject sensor: PressureSensor;
        requirement: The pressure sensor shall monitor cuff pressure to ensure it does not exceed safe levels.
    }
}
