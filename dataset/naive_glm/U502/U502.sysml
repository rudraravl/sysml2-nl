package FrothPumpingSubsystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----
    value def PressureValue :> Real { unit "Pa"; }
    value def FlowRateValue :> Real { unit "m^3/s"; }
    value def RotationalSpeed :> Real { unit "rpm"; }
    value def TemperatureValue :> Real { unit "K"; }
    value def PowerValue :> Real { unit "W"; }
    value def VoltageValue :> Real { unit "V"; }
    value def CurrentValue :> Real { unit "A"; }
    value def DiameterValue :> Real { unit "m"; }
    value def LengthValue :> Real { unit "m"; }
    value def MassFraction :> Real { unit "1"; }
    value def VolumeFraction :> Real { unit "1"; }

    // ---- Item Types ----
    item def Froth {
        attribute gasFraction : VolumeFraction;
        attribute solidFraction : MassFraction;
        attribute temperature : TemperatureValue;
        attribute density : Real { unit "kg/m^3"; }
    }

    item def Gas;
    item def SolidParticle {
        attribute meanDiameter : DiameterValue;
        attribute hardness : Real { unit "Mohs"; }
    }

    // ---- Port Definitions ----
    port def FluidPort {
        in item froth : Froth;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def ElectricalPort {
        in attribute voltage : VoltageValue;
        in attribute current : CurrentValue;
    }

    port def SignalPort {
        in attribute pressureReading : PressureValue;
        in attribute flowReading : FlowRateValue;
        out attribute command : Real;
    }

    // ---- Requirements ----
    requirement def TransportFrothRequirement {
        subject : FrothPumpingSubsystem;
        objective {
            doc /* The subsystem shall transport froth from the supply tank to the receiving tank. */
        }
    }

    requirement def PumpWearResistanceRequirement {
        subject : FrothPump;
        attribute minHardness : Real { unit "HRC"; } = 60;
        objective {
            doc /* The pump casing shall be wear-resistant high-chrome white iron. */
        }
    }

    requirement def SealIntegrityRequirement {
        subject : FrothPump;
        objective {
            doc /* The pump shall use a double mechanical seal to prevent leaks. */
        }
    }

    requirement def FlowRegulationRequirement {
        subject : ControlValve;
        objective {
            doc /* The control valve shall regulate flow rate in the discharge line. */
        }
    }

    requirement def MonitoringRequirement {
        subject : ControlSystem;
        objective {
            doc /* The control system shall monitor suction pressure, discharge pressure, and discharge flow rate. */
        }
    }

    requirement def SafeOperationRequirement {
        subject : ControlSystem;
        objective {
            doc /* The control system shall detect low flow, excessive discharge pressure, and cavitation, and react accordingly. */
        }
    }

    // ---- Part Definitions ----
    part def SupplyTank {
        port outlet : FluidPort;
        attribute capacity : VolumeValue { unit "m^3"; } = 50.0;
        attribute fillLevel : Real { unit "m"; } = 4.0;
        item storedFroth : Froth;
    }

    part def ReceivingTank {
        port inlet : FluidPort;
        attribute capacity : VolumeValue { unit "m^3"; } = 60.0;
        attribute fillLevel : Real { unit "m"; } = 1.0;
        item receivedFroth : Froth;
    }

    part def Piping {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute diameter : DiameterValue;
        attribute length : LengthValue;
        attribute linedWithRubber : Boolean = true;
        attribute material : String = "steel";
    }

    part def SuctionPiping :> Piping {
        attribute diameter : DiameterValue = 0.3;
        attribute length : LengthValue = 5.0;
    }

    part def DischargePiping :> Piping {
        attribute diameter : DiameterValue = 0.2;
        attribute length : LengthValue = 8.0;
    }

    part def ControlValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port controlSignal : SignalPort;
        attribute position : Real { unit "1"; } = 0.0;
        attribute maxFlowRate : FlowRateValue = 0.5;

        action def regulateFlow {
            in cmd : Real;
            out valvePosition : Real;
            // Map command to valve opening
        }
    }

    part def PressureGauge {
        port measurement : FluidPort;
        port signalOut : SignalPort;
        attribute measuredPressure : PressureValue;
    }

    part def FlowMeter {
        port measurement : FluidPort;
        port signalOut : SignalPort;
        attribute measuredFlowRate : FlowRateValue;
    }

    part def ElectricMotor {
        port powerIn : ElectricalPort;
        port driveOut : ~ElectricalPort;
        attribute ratedPower : PowerValue = 75000;
        attribute ratedSpeed : RotationalSpeed = 1480;
        attribute currentSpeed : RotationalSpeed = 0;
        attribute running : Boolean = false;
    }

    part def Impeller {
        attribute bladeCount : Integer = 3;
        attribute material : String = "high-chrome white iron";
        attribute diameter : DiameterValue = 0.45;
    }

    part def PumpCasing {
        attribute material : String = "high-chrome white iron";
        attribute minHardness : Real { unit "HRC"; } = 62;
        attribute inletDiameter : DiameterValue = 0.3;
        attribute outletDiameter : DiameterValue = 0.2;
    }

    part def MechanicalSeal {
        attribute sealType : String = "double mechanical";
        attribute primarySealIntegrity : Boolean = true;
        attribute secondarySealIntegrity : Boolean = true;
    }

    part def DriveShaft {
        attribute material : String = "stainless steel";
        attribute length : LengthValue = 0.6;
        attribute diameter : DiameterValue = 0.05;
    }

    part def FrothPump {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port drivePort : ~ElectricalPort;
        port controlPort : SignalPort;

        part casing : PumpCasing;
        part impeller : Impeller;
        part seal : MechanicalSeal;
        part shaft : DriveShaft;

        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute speed : RotationalSpeed = 0;

        action def pressurize {
            in frothIn : Froth;
            in pumpSpeed : RotationalSpeed;
            out frothOut : Froth;
            out dischargePressure : PressureValue;
        }
    }

    part def ControlSystem {
        port suctionPressureSignal : SignalPort;
        port dischargePressureSignal : SignalPort;
        port flowSignal : SignalPort;
        port valveControl : SignalPort;
        port motorControl : SignalPort;

        attribute targetFlowRate : FlowRateValue = 0.3;
        attribute maxDischargePressure : PressureValue = 800000;
        attribute minFlowRate : FlowRateValue = 0.05;
        attribute cavitationDetected : Boolean = false;

        action def evaluateConditions {
            in suctionP : PressureValue;
            in dischargeP : PressureValue;
            in flow : FlowRateValue;
            out alarm : Boolean;
            out action : String;
        }

        state def PumpOperation {
            entry;
            state stopped;
            state priming;
            state accelerating;
            state running;
            state faultShutdown;
            state emergencyShutdown;

            transition stopped_to_priming
                first stopped then priming
                when (controlPort.command > 0);

            transition priming_to_accelerating
                first priming then accelerating
                when (suctionPressureSignal.pressureReading > 80000);

            transition accelerating_to_running
                first accelerating then running
                when (motorControl.command >= 1.0);

            transition running_to_faultShutdown
                first running then faultShutdown
                when (flowSignal.flowReading < minFlowRate
                    or dischargePressureSignal.pressureReading > maxDischargePressure
                    or cavitationDetected);

            transition running_to_stopped
                first running then stopped
                when (controlPort.command == 0);

            transition faultShutdown_to_stopped
                first faultShutdown then stopped
                when (motorControl.command == 0);

            transition any_to_emergencyShutdown
                first (stopped | priming | accelerating | running) then emergencyShutdown
                when (controlPort.command < 0);

            transition emergencyShutdown_to_stopped
                first emergencyShutdown then stopped
                when (motorControl.command == 0);
        }
    }

    // ---- Top-level Subsystem ----
    part def FrothPumpingSubsystem {
        satisfy TransportFrothRequirement by self;

        part supplyTank : SupplyTank;
        part receivingTank : ReceivingTank;
        part suctionPiping : SuctionPiping;
        part dischargePiping : DischargePiping;
        part pump : FrothPump {
            satisfy PumpWearResistanceRequirement by self.casing;
            satisfy SealIntegrityRequirement by self.seal;
        }
        part motor : ElectricMotor;
        part controlValve : ControlValve {
            satisfy FlowRegulationRequirement by self;
        }
        part suctionPressureGauge : PressureGauge;
        part dischargePressureGauge : PressureGauge;
        part flowMeter : FlowMeter;
        part controller : ControlSystem {
            satisfy MonitoringRequirement by self;
            satisfy SafeOperationRequirement by self;
        }

        // Connections
        connection supplyToSuction connect supplyTank.outlet to suctionPiping.inlet;
        connection suctionToPump connect suctionPiping.outlet to pump.suctionPort;
        connection pumpToDischarge connect pump.dischargePort to dischargePiping.inlet;
        connection dischargeToValve connect dischargePiping.outlet to controlValve.inlet;
        connection valveToReceiving connect controlValve.outlet to receivingTank.inlet;

        connection motorDrive connect motor.driveOut to pump.drivePort;

        connection suctionGaugeFluid connect pump.suctionPort to suctionPressureGauge.measurement;
        connection dischargeGaugeFluid connect pump.dischargePort to dischargePressureGauge.measurement;
        connection flowMeterFluid connect controlValve.outlet to flowMeter.measurement;

        connection suctionGaugeSignal connect suctionPressureGauge.signalOut to controller.suctionPressureSignal;
        connection dischargeGaugeSignal connect dischargePressureGauge.signalOut to controller.dischargePressureSignal;
        connection flowMeterSignal connect flowMeter.signalOut to controller.flowSignal;

        connection valveControlSignal connect controller.valveControl to controlValve.controlSignal;
        connection motorControlSignal connect controller.motorControl to motor.powerIn;

        // Behavior: overall operation
        action def operateSubsystem {
            in startCommand : Boolean;
            out frothDelivered : Froth;

            // Start sequence
            if startCommand {
                controller.controlPort.command := 1.0;
            }
            // Pump operation state machine governs transitions
        }
    }
}
