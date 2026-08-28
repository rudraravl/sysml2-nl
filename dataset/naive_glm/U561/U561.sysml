package IndustrialFluidTransferSystem {
    import ScalarValues::*;
    import ISQ::*;

    value def PressureValue :> Real { unit 'Pa'; }
    value def FlowRateValue :> Real { unit 'm3/s'; }
    value def TorqueValue :> Real { unit 'N.m'; }
    value def RotationalSpeedValue :> Real { unit 'rad/s'; }
    value def VolumeValue :> Real { unit 'm3'; }
    value def EfficiencyValue :> Real { unit '1'; }
    value def FrequencyValue :> Real { unit 'Hz'; }
    value def PowerValue :> Real { unit 'W'; }
    value def LengthValue :> Real { unit 'm'; }

    item def Liquid;
    item def ProcessFluid :> Liquid;

    attribute def FluidState {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : Real { unit 'K'; } = 293.15;
    }

    port def FluidPort {
        in out item flow ProcessFluid;
        attribute state : FluidState;
    }

    port def MechanicalDrivePort {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : RotationalSpeedValue;
    }

    port def ElectricalPowerPort {
        attribute voltage : Real { unit 'V'; };
        attribute current : Real { unit 'A'; };
    }

    part def SourceReservoir {
        attribute capacity : VolumeValue = 5.0;
        attribute currentLevel : VolumeValue = 4.0;
        attribute ambientPressure : PressureValue = 101325;
        port fluidOut : FluidPort;
        exhibit {
            action supplyFluid out ProcessFluid;
        }
    }

    part def Stator {
        attribute innerDiameter : LengthValue = 0.12;
        attribute housingLength : LengthValue = 0.25;
        attribute material : String = "StainlessSteel";
    }

    part def SinusoidalRotor {
        attribute lobeCount : Integer = 2;
        attribute waveAmplitude : LengthValue = 0.015;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute phaseAngle : Real { unit 'rad'; } = 0.0;
        port driveInput : MechanicalDrivePort;
        exhibit {
            action rotate in driveInput;
        }
    }

    part def SealingSystem {
        attribute sealIntegrity : Real = 1.0;
        attribute maxSealPressure : PressureValue = 600000;
        attribute sealType : String = "MechanicalLip";
    }

    part def SinusoidalPump {
        attribute nominalFlowRate : FlowRateValue = 0.001;
        attribute maxPressure : PressureValue = 500000;
        attribute efficiency : EfficiencyValue = 0.85;
        attribute pulsationFrequency : FrequencyValue = 2.0;
        attribute displacementPerRevolution : VolumeValue = 0.0001;

        port inlet : FluidPort;
        port outlet : FluidPort;
        port driveInput : MechanicalDrivePort;

        part stator : Stator;
        part rotor : SinusoidalRotor;
        part sealing : SealingSystem;

        connection rotorDrive connect driveInput to rotor.driveInput;

        exhibit PumpControlStateMachine {
            attribute commandStart : Boolean = false;
            attribute commandStop : Boolean = false;
            attribute commandHighPressure : Boolean = false;
            attribute measuredSpeed : RotationalSpeedValue;
            attribute measuredPressure : PressureValue;

            state stopped {
                entry action { driveInput.rotationalSpeed := 0; }
            }
            state starting {
                entry action { driveInput.rotationalSpeed := 50; }
            }
            state running {
                state normalOperation {
                    entry action { outlet.state.pressure := 300000; }
                }
                state highPressureMode {
                    entry action { outlet.state.pressure := 450000; }
                }
                transition normalToHigh
                    from normalOperation to highPressureMode
                    when commandHighPressure == true;
                transition highToNormal
                    from highPressureMode to normalOperation
                    when commandHighPressure == false;
            }
            state stopping {
                entry action { driveInput.rotationalSpeed := 20; }
            }

            transition stopToStart
                from stopped to starting
                when commandStart == true;
            transition startToRun
                from starting to running
                when measuredSpeed >= 100;
            transition runToStop
                from running to stopping
                when commandStop == true;
            transition stopComplete
                from stopping to stopped
                when measuredSpeed == 0;
        }
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue = 1500;
        attribute ratedSpeed : RotationalSpeedValue = 157;
        attribute ratedTorque : TorqueValue = 9.5;
        attribute currentTorque : TorqueValue;
        attribute currentSpeed : RotationalSpeedValue;
        port driveOutput : MechanicalDrivePort;
        port powerInput : ElectricalPowerPort;
        exhibit {
            action generateTorque out driveOutput;
        }
    }

    part def ProcessVessel {
        attribute operatingPressure : PressureValue = 300000;
        attribute capacity : VolumeValue = 2.0;
        attribute currentLevel : VolumeValue = 0.0;
        attribute maxAllowablePressure : PressureValue = 500000;
        port fluidIn : FluidPort;
        exhibit {
            action receiveFluid in ProcessFluid;
        }
    }

    part def FluidTransferSystem {
        attribute systemEfficiency : EfficiencyValue = 0.82;
        attribute totalRunTime : Real { unit 's'; } = 0.0;

        part reservoir : SourceReservoir;
        part pump : SinusoidalPump;
        part motor : ElectricMotor;
        part vessel : ProcessVessel;

        connection reservoirToPump connect reservoir.fluidOut to pump.inlet;
        connection pumpToVessel connect pump.outlet to vessel.fluidIn;
        connection motorToPump connect motor.driveOutput to pump.driveInput;

        exhibit {
            action transferFluid in ProcessFluid;
        }
    }

    requirement def SinusoidalFlowRequirement {
        attribute requiredPulsationFrequency : FrequencyValue = 2.0;
        attribute flowPattern : String = "sinusoidal";
        subject pump : SinusoidalPump;
        require pump.pulsationFrequency == requiredPulsationFrequency;
        require pump.rotor.lobeCount == 2;
    }

    requirement def PressureLimitRequirement {
        attribute maxAllowablePressure : PressureValue = 500000;
        subject vessel : ProcessVessel;
        subject pump : SinusoidalPump;
        require vessel.operatingPressure <= maxAllowablePressure;
        require pump.maxPressure <= maxAllowablePressure;
    }

    requirement def EfficiencyRequirement {
        attribute minEfficiency : EfficiencyValue = 0.80;
        subject system : FluidTransferSystem;
        require system.systemEfficiency >= minEfficiency;
    }

    requirement def FlowRateRequirement {
        attribute targetFlowRate : FlowRateValue = 0.001;
        subject pump : SinusoidalPump;
        require pump.nominalFlowRate >= targetFlowRate;
    }

    requirement def SystemPerformanceRequirement {
        subject system : FluidTransferSystem;
        satisfy SinusoidalFlowRequirement;
        satisfy PressureLimitRequirement;
        satisfy EfficiencyRequirement;
        satisfy FlowRateRequirement;
    }
}
