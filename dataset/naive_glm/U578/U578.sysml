package VoluteCentrifugalPump {

    import ISQ::*;
    import ISQBase::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value def RotationalSpeedValue :> Real { unit "rev/min"; }
    value def VolumetricFlowRateValue :> Real { unit "m^3/s"; }
    value def PressureValue :> Real { unit "Pa"; }
    value def VelocityValue :> Real { unit "m/s"; }
    value def TorqueValue :> Real { unit "N*m"; }
    value def EfficiencyValue :> Real { unit "1"; }
    value def TemperatureValue :> Real { unit "K"; }
    value def LengthValue :> Real { unit "m"; }
    value def AreaValue :> Real { unit "m^2"; }
    value def DensityValue :> Real { unit "kg/m^3"; }
    value def DynamicViscosityValue :> Real { unit "Pa*s"; }

    // ---- Item definitions ----
    item def Fluid {
        attribute density : DensityValue = 1000 [kg/m^3];
        attribute dynamicViscosity : DynamicViscosityValue = 0.001 [Pa*s];
        attribute vaporPressure : PressureValue = 2300 [Pa];
        attribute temperature : TemperatureValue = 293.15 [K];
    }

    item def StartCommand;
    item def StopCommand;

    // ---- Port definitions ----
    port def RotationalPowerPort {
        out attribute torque : TorqueValue;
        out attribute speed : RotationalSpeedValue;
    }

    port def FluidPort {
        attribute pressure : PressureValue;
        attribute volumetricFlowRate : VolumetricFlowRateValue;
        attribute temperature : TemperatureValue;
        in item fluid : Fluid;
    }

    // ---- External drive shaft ----
    part def ExternalDriveShaft {
        port out powerOut : RotationalPowerPort;
        attribute nominalSpeed : RotationalSpeedValue = 1750 [rev/min];
        attribute suppliedTorque : TorqueValue = 45 [N*m];
    }

    // ---- Impeller ----
    part def Impeller {
        port in powerIn : RotationalPowerPort;
        port in suction : FluidPort;
        port out discharge : FluidPort;

        attribute bladeCount : Integer = 7;
        attribute impellerDiameter : LengthValue = 0.20 [m];
        attribute currentSpeed : RotationalSpeedValue = 0 [rev/min];
        attribute outletVelocity : VelocityValue = 0 [m/s];
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue;

        action def AccelerateFluid {
            in fluid : Fluid;
            in speed : RotationalSpeedValue;
            out acceleratedFluid : Fluid;
            out outletVelocity : VelocityValue;
        }

        action def Spin {
            in torque : TorqueValue;
            in targetSpeed : RotationalSpeedValue;
            out speed : RotationalSpeedValue;
        }
    }

    // ---- Volute casing ----
    part def VoluteCasing {
        port in inlet : FluidPort;
        port out outlet : FluidPort;

        attribute inletArea : AreaValue = 0.012 [m^2];
        attribute outletArea : AreaValue = 0.060 [m^2];
        attribute pressureRise : PressureValue = 0 [Pa];
        attribute kineticEnergyConverted : Boolean = false;

        action def DiffuseFluid {
            in fluid : Fluid;
            in inletVelocity : VelocityValue;
            out fluidOut : Fluid;
            out pressureRise : PressureValue;
        }
    }

    // ---- Discharge pipe ----
    part def DischargePipe {
        port in inlet : FluidPort;
        port out dischargePort : FluidPort;

        attribute pipeDiameter : LengthValue = 0.10 [m];
        attribute pipeLength : LengthValue = 1.5 [m];
        attribute frictionLoss : PressureValue = 0 [Pa];
    }

    // ---- Pump system ----
    part def VoluteCentrifugalPumpSystem {

        port in driveInput : RotationalPowerPort;
        port in suctionPort : FluidPort;
        port out dischargePort : FluidPort;

        attribute nominalFlowRate : VolumetricFlowRateValue = 0.050 [m^3/s];
        attribute nominalPressureRise : PressureValue = 200000 [Pa];
        attribute requiredEfficiency : EfficiencyValue = 0.75;
        attribute measuredFlowRate : VolumetricFlowRateValue = 0 [m^3/s];
        attribute measuredPressureRise : PressureValue = 0 [Pa];
        attribute measuredEfficiency : EfficiencyValue = 0 [1];
        attribute cavitationDetected : Boolean = false;
        attribute cavitationThresholdPressure : PressureValue = 3000 [Pa];

        part impeller : Impeller {
            port in powerIn : RotationalPowerPort;
            port in suction : FluidPort;
            port out discharge : FluidPort;
        }

        part voluteCasing : VoluteCasing {
            port in inlet : FluidPort;
            port out outlet : FluidPort;
        }

        part dischargePipe : DischargePipe {
            port in inlet : FluidPort;
            port out dischargePort : FluidPort;
        }

        connection driveConnection connect driveInput to impeller.powerIn;
        connection suctionConnection connect suctionPort to impeller.suction;
        connection impellerToVolute connect impeller.discharge to voluteCasing.inlet;
        connection voluteToPipe connect voluteCasing.outlet to dischargePipe.inlet;
        connection dischargeConnection connect dischargePipe.dischargePort to dischargePort;

        // ---- Operational state machine ----
        state PumpOperation {

            state stopped {
                entry action {
                    impeller.currentSpeed = 0 [rev/min];
                    impeller.outletVelocity = 0 [m/s];
                    voluteCasing.pressureRise = 0 [Pa];
                    measuredFlowRate = 0 [m^3/s];
                    measuredPressureRise = 0 [Pa];
                }
            }

            state starting {
                entry action {
                    impeller.Spin(driveInput.torque, 1750 [rev/min]);
                }
                do action RampUp {
                    in torque : TorqueValue = driveInput.torque;
                    in target : RotationalSpeedValue = 1750 [rev/min];
                    out speed : RotationalSpeedValue = impeller.currentSpeed;
                }
            }

            state running {
                entry action {
                    impeller.AccelerateFluid(suctionPort.fluid, impeller.currentSpeed);
                    voluteCasing.DiffuseFluid(impeller.discharge.fluid, impeller.outletVelocity);
                }
                do action PumpFluid {
                    in fluid : Fluid = suctionPort.fluid;
                    out pressurizedFluid : Fluid = dischargePort.fluid;
                }
            }

            state stopping {
                do action CoastDown {
                    out speed : RotationalSpeedValue = impeller.currentSpeed;
                }
            }

            transition initial to stopped;

            transition from stopped to starting
                accept StartCommand;

            transition from starting to running
                when impeller.currentSpeed >= 1750 [rev/min];

            transition from running to stopping
                accept StopCommand;

            transition from running to stopping
                when cavitationDetected == true;

            transition from stopping to stopped
                when impeller.currentSpeed <= 0 [rev/min];
        }

        // ---- Cavitation monitoring action ----
        action def MonitorCavitation {
            in inletPressure : PressureValue = impeller.inletPressure;
            out cavitationFlag : Boolean = cavitationDetected;
            
            if inletPressure < cavitationThresholdPressure {
                cavitationDetected = true;
            } else {
                cavitationDetected = false;
            }
        }
    }

    // ---- Top-level context binding the external drive shaft to the pump ----
    part PumpAssembly {
        part driveShaft : ExternalDriveShaft {
            port out powerOut : RotationalPowerPort;
        }

        part pump : VoluteCentrifugalPumpSystem {
            port in driveInput : RotationalPowerPort;
            port in suctionPort : FluidPort;
            port out dischargePort : FluidPort;
        }

        connection driveShaftToPump connect driveShaft.powerOut to pump.driveInput;
    }

    // ---- Requirements ----
    req def FlowRateRequirement {
        subject pump : VoluteCentrifugalPumpSystem;
        requirement pump.measuredFlowRate >= 0.040 [m^3/s];
    }

    req def PressureRiseRequirement {
        subject pump : VoluteCentrifugalPumpSystem;
        requirement pump.measuredPressureRise >= 180000 [Pa];
    }

    req def HydraulicEfficiencyRequirement {
        subject pump : VoluteCentrifugalPumpSystem;
        requirement pump.measuredEfficiency >= 0.70;
    }

    req def CavitationProtectionRequirement {
        subject pump : VoluteCentrifugalPumpSystem;
        requirement {
            when pump.cavitationDetected == true then
                pump.PumpOperation.activeState == pump.PumpOperation.stopping
        }
    }

    req def SafeShutdownRequirement {
        subject pump : VoluteCentrifugalPumpSystem;
        requirement {
            when pump.PumpOperation.activeState == pump.PumpOperation.stopping then
                pump.impeller.currentSpeed decreases monotonically to 0 [rev/min]
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction FlowRateRequirement by pump.measuredFlowRate;
    satisfaction PressureRiseRequirement by pump.measuredPressureRise;
    satisfaction HydraulicEfficiencyRequirement by pump.measuredEfficiency;
    satisfaction CavitationProtectionRequirement by pump.PumpOperation;
    satisfaction SafeShutdownRequirement by pump.PumpOperation;

}
