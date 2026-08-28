package FlexibleImpellerPumpSystem {
    import ISQ::*;
    import ScalarValues::*;

    enum def CommandKind { start; stop; emergencyStop; }

    item def Fluid {
        attribute name : String;
        attribute density : MassDensityValue;
        attribute viscosity : DynamicViscosityValue;
        attribute temperature : TemperatureValue;
        attribute entrainedAir : Boolean;
        attribute delicate : Boolean;
    }

    port def FluidPort {
        attribute pressure : PressureValue;
        attribute flowRate : VolumeFlowRateValue;
        inout fluid : Fluid;
    }

    port def ElectricalPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute frequency : FrequencyValue;
        in energized : Boolean;
    }

    port def MechanicalPort {
        attribute torque : TorqueValue;
        attribute speed : RotationalFrequencyValue;
    }

    port def CommandPort {
        in command : CommandKind;
    }

    part def FlexibleImpeller {
        attribute bladeCount : Integer = 8;
        attribute material : String = "NBR";
        attribute shoreHardness : Real;
        attribute maxDryRunTime : TimeValue = 30 [s];
        attribute maxOperatingTemp : TemperatureValue = 90 [degC];
        attribute minOperatingTemp : TemperatureValue = -10 [degC];
        attribute wearLife : TimeValue = 2500 [h];
        port shaftInterface : MechanicalPort;
    }

    part def PumpCasing {
        attribute material : String = "Bronze";
        attribute eccentricity : LengthValue;
        attribute inletDiameter : LengthValue;
        attribute outletDiameter : LengthValue;
        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    part def DriveShaft {
        attribute material : String = "StainlessSteel316";
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute maxTorque : TorqueValue;
        port motorSide : MechanicalPort;
        port impellerSide : MechanicalPort;
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue = 750 [W];
        attribute ratedSpeed : RotationalFrequencyValue = 1450 [rev/min];
        attribute supplyVoltage : ElectricPotentialValue = 230 [V];
        attribute supplyFrequency : FrequencyValue = 50 [Hz];
        attribute efficiency : Real = 0.85;
        port electricalIn : ElectricalPort;
        port mechanicalOut : MechanicalPort;
    }

    part def CheckValve {
        attribute crackingPressure : PressureValue;
        attribute orientation : String;
        attribute material : String = "StainlessSteel";
        port upstream : FluidPort;
        port downstream : FluidPort;
    }

    part def PumpUnit {
        part impeller : FlexibleImpeller;
        part casing : PumpCasing;
        part shaft : DriveShaft;
        port inlet : FluidPort;
        port outlet : FluidPort;

        connection shaftToImpeller connect shaft.impellerSide to impeller.shaftInterface {
            attribute couplingType : String = "Keyed";
        }
        connection inletConnect connect inlet to casing.inlet;
        connection outletConnect connect casing.outlet to outlet;

        attribute displacementPerRev : VolumeValue = 0.000035 [m^3];
    }

    part def FlexibleImpellerPumpSystem {
        part motor : ElectricMotor;
        part pump : PumpUnit;
        part suctionValve : CheckValve {
            attribute orientation = "Suction";
        }
        part dischargeValve : CheckValve {
            attribute orientation = "Discharge";
        }

        port electricalInput : ElectricalPort;
        port commandInput : CommandPort;
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;

        connection powerIn connect electricalInput to motor.electricalIn;
        connection motorShaft connect motor.mechanicalOut to pump.shaft.motorSide;
        connection suctionLine connect suctionPort to suctionValve.upstream;
        connection suctionToPump connect suctionValve.downstream to pump.inlet;
        connection dischargeFromPump connect pump.outlet to dischargeValve.upstream;
        connection dischargeLine connect dischargeValve.downstream to dischargePort;

        attribute currentSpeed : RotationalFrequencyValue;
        attribute currentFlow : VolumeFlowRateValue;
        attribute currentPressure : PressureValue;
        attribute primed : Boolean;

        exhibit stateMachine PumpOperation {
            entry : currentSpeed = 0 [rev/min];

            state off {
                entry : currentSpeed = 0 [rev/min];
                entry : primed = false;
            }

            state starting {
                entry : currentSpeed = 0 [rev/min];
                do action Accelerate {
                    // Ramp motor speed toward rated speed
                    currentSpeed = motor.ratedSpeed * 0.5;
                    currentSpeed = motor.ratedSpeed;
                }
            }

            state running {
                entry : currentFlow = pump.displacementPerRev * currentSpeed;
                entry : currentPressure = 1.8 [bar];
                entry : primed = true;
                do action PumpFluid {
                    // Positive displacement action: blades flex and straighten
                    // drawing fluid through inlet and expelling through outlet
                    currentFlow = pump.displacementPerRev * currentSpeed;
                }
            }

            state stopping {
                entry : currentSpeed = currentSpeed * 0.5;
                do action Decelerate {
                    currentSpeed = 0 [rev/min];
                }
            }

            transition off_to_starting
                from off to starting
                when commandInput.command == CommandKind::start;

            transition starting_to_running
                from starting to running
                when currentSpeed >= motor.ratedSpeed;

            transition running_to_stopping
                from running to stopping
                when commandInput.command == CommandKind::stop;

            transition stopping_to_off
                from stopping to off
                when currentSpeed == 0 [rev/min];

            transition off_emergency
                from off to off
                when commandInput.command == CommandKind::emergencyStop;

            transition starting_emergency
                from starting to off
                when commandInput.command == CommandKind::emergencyStop;

            transition running_emergency
                from running to off
                when commandInput.command == CommandKind::emergencyStop;

            transition stopping_emergency
                from stopping to off
                when commandInput.command == CommandKind::emergencyStop;
        }
    }

    requirement def FlowRateRequirement {
        attribute requiredFlowRate : VolumeFlowRateValue = 50 [L/min];
        subject pump : FlexibleImpellerPumpSystem;
        require { pump.dischargePort.flowRate >= requiredFlowRate; }
    }

    requirement def DischargePressureRequirement {
        attribute requiredPressure : PressureValue = 2 [bar];
        subject pump : FlexibleImpellerPumpSystem;
        require { pump.dischargePort.pressure >= requiredPressure; }
    }

    requirement def ImpellerDurabilityRequirement {
        attribute minWearLife : TimeValue = 2000 [h];
        attribute maxAllowedDryRun : TimeValue = 30 [s];
        attribute minOperatingTemp : TemperatureValue = -10 [degC];
        attribute maxOperatingTemp : TemperatureValue = 80 [degC];
        subject impeller : FlexibleImpeller;
        require { impeller.wearLife >= minWearLife; }
        require { impeller.maxDryRunTime <= maxAllowedDryRun; }
        require { impeller.minOperatingTemp <= minOperatingTemp; }
        require { impeller.maxOperatingTemp >= maxOperatingTemp; }
    }

    requirement def SelfPrimingRequirement {
        subject pump : FlexibleImpellerPumpSystem;
        require { pump.pump.impeller.bladeCount >= 6; }
        require { pump.pump.casing.eccentricity > 0 [mm]; }
    }

    requirement def BackflowPreventionRequirement {
        subject pump : FlexibleImpellerPumpSystem;
        require { pump.suctionValve.crackingPressure > 0 [Pa]; }
        require { pump.dischargeValve.crackingPressure > 0 [Pa]; }
    }

    requirement def DriveShaftStrengthRequirement {
        attribute minDiameter : LengthValue = 16 [mm];
        subject shaft : DriveShaft;
        require { shaft.diameter >= minDiameter; }
        require { shaft.maxTorque >= 5 [N*m]; }
    }

    requirement def MotorPowerRequirement {
        attribute minRatedPower : PowerValue = 500 [W];
        subject motor : ElectricMotor;
        require { motor.ratedPower >= minRatedPower; }
    }

    requirement def ViscousFluidHandlingRequirement {
        attribute maxViscosity : DynamicViscosityValue = 1 [Pa*s];
        subject pump : FlexibleImpellerPumpSystem;
        require { pump.suctionPort.fluid.viscosity <= maxViscosity; }
    }

    requirement def EntrainedAirHandlingRequirement {
        subject pump : FlexibleImpellerPumpSystem;
        require { pump.suctionPort.fluid.entrainedAir == true; }
    }
}
