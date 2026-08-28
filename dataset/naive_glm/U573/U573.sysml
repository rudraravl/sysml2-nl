package TrompeSystem {
    import ScalarValues::*;

    // ---- Item Definitions ----
    item def Water {
        attribute density : Real = 1000.0; // kg/m^3
        attribute temperature : Real; // K
    }

    item def AtmosphericAir {
        attribute pressure : Real = 101325.0; // Pa
        attribute temperature : Real; // K
    }

    item def AirWaterMixture {
        attribute airVolumeFraction : Real; // 0..1
        attribute pressure : Real; // Pa
        attribute temperature : Real; // K
    }

    item def CompressedAir {
        attribute pressure : Real; // Pa
        attribute temperature : Real; // K
        attribute volume : Real; // m^3
    }

    // ---- Value Types ----
    value def PressureValue :> Real { doc "Pressure in Pascals"; }
    value def DepthValue :> Real { doc "Depth in metres"; }
    value def LengthValue :> Real { doc "Length in metres"; }
    value def FlowRateValue :> Real { doc "Volumetric flow rate in m^3/s"; }
    value def VolumeValue :> Real { doc "Volume in m^3"; }
    value def FractionValue :> Real { doc "Dimensionless fraction 0..1"; }
    value def EfficiencyValue :> Real { doc "Dimensionless efficiency 0..1"; }
    value def TemperatureValue :> Real { doc "Temperature in Kelvin"; }
    value def PowerValue :> Real { doc "Power in Watts"; }

    // ---- Port Definitions ----
    port def WaterInPort {
        in water : Water;
    }
    port def WaterOutPort {
        out water : Water;
    }
    port def AirInPort {
        in air : AtmosphericAir;
    }
    port def CompressedAirOutPort {
        out compressedAir : CompressedAir;
    }
    port def MixtureOutPort {
        out mixture : AirWaterMixture;
    }
    port def MixtureInPort {
        in mixture : AirWaterMixture;
    }

    // ---- Intake Section ----
    part def IntakeSection {
        port waterIn : WaterInPort;
        port airIn : AirInPort;
        port mixtureOut : MixtureOutPort;

        attribute designFlowRate : FlowRateValue = 2.0;
        attribute entrainmentEfficiency : EfficiencyValue = 0.6;
        attribute intakeArea : Real = 1.5; // m^2

        action def EntrainAir {
            in water : Water;
            in air : AtmosphericAir;
            out mixture : AirWaterMixture;
        }

        action entrain : EntrainAir {
            in water = waterIn.water;
            in air = airIn.air;
            out mixture = mixtureOut.mixture;
        }
    }

    // ---- Vertical Shaft ----
    part def VerticalShaft {
        port mixtureIn : MixtureInPort;
        port mixtureOut : MixtureOutPort;

        attribute shaftDepth : DepthValue = 50.0;
        attribute shaftDiameter : LengthValue = 1.0;
        attribute inletPressure : PressureValue = 101325.0;
        attribute outletPressure : PressureValue;

        action def CompressDescendingMixture {
            in mixtureIn : AirWaterMixture;
            out mixtureOut : AirWaterMixture;
        }

        action compress : CompressDescendingMixture {
            in mixtureIn = mixtureIn.mixture;
            out mixtureOut = mixtureOut.mixture;
        }

        // Hydrostatic pressure increases with depth: P = P0 + rho*g*h
        compute outletPressure : PressureValue = inletPressure + 1000.0 * 9.81 * shaftDepth;
    }

    // ---- Separation Vessel ----
    part def SeparationVessel {
        port mixtureIn : MixtureInPort;
        port airOut : CompressedAirOutPort;
        port waterOut : WaterOutPort;

        attribute vesselVolume : VolumeValue = 20.0;
        attribute operatingPressure : PressureValue;
        attribute separationEfficiency : EfficiencyValue = 0.95;
        attribute waterLevel : Real; // m

        action def SeparateMixture {
            in mixture : AirWaterMixture;
            out compressedAir : CompressedAir;
            out water : Water;
        }

        action separate : SeparateMixture {
            in mixture = mixtureIn.mixture;
            out compressedAir = airOut.compressedAir;
            out water = waterOut.water;
        }
    }

    // ---- Tailrace Outlet ----
    part def TailraceOutlet {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;

        attribute channelLength : LengthValue = 30.0;
        attribute channelSlope : Real = 0.05;
        attribute dischargeFlowRate : FlowRateValue;

        action def DischargeWater {
            in waterIn : Water;
            out waterOut : Water;
        }

        action discharge : DischargeWater {
            in waterIn = waterIn.water;
            out waterOut = waterOut.water;
        }
    }

    // ---- Trompe System ----
    part def Trompe {
        attribute systemName : String = "Trompe Passive Hydraulic Air Compressor";
        attribute sourceHead : LengthValue = 5.0;
        attribute shaftDepth : DepthValue = 50.0;
        attribute designFlowRate : FlowRateValue = 2.0;
        attribute theoreticalOutputPressure : PressureValue;
        attribute estimatedAirFlowRate : FlowRateValue;
        attribute systemEfficiency : EfficiencyValue = 0.55;

        part intake : IntakeSection {
            redefines designFlowRate = 2.0;
        }
        part shaft : VerticalShaft {
            redefines shaftDepth = 50.0;
        }
        part vessel : SeparationVessel {
            redefines operatingPressure = shaft.outletPressure;
        }
        part tailrace : TailraceOutlet {
            redefines dischargeFlowRate = 2.0;
        }

        // External interface ports
        port externalWaterIn : WaterInPort;
        port externalAirIn : AirInPort;
        port compressedAirDelivery : CompressedAirOutPort;
        port tailwaterDischarge : WaterOutPort;

        flow connection extWaterFlow from externalWaterIn to intake.waterIn;
        flow connection extAirFlow from externalAirIn to intake.airIn;
        flow connection mixtureFlow1 from intake.mixtureOut to shaft.mixtureIn;
        flow connection mixtureFlow2 from shaft.mixtureOut to vessel.mixtureIn;
        flow connection compressedAirFlow from vessel.airOut to compressedAirDelivery;
        flow connection tailwaterFlow from vessel.waterOut to tailrace.waterIn;
        flow connection dischargeFlow from tailrace.waterOut to tailwaterDischarge;

        // Theoretical output pressure: P = P_atm + rho*g*h
        compute theoreticalOutputPressure : PressureValue =
            101325.0 + 1000.0 * 9.81 * shaftDepth;

        // Estimated compressed air flow rate
        compute estimatedAirFlowRate : FlowRateValue =
            designFlowRate * intake.entrainmentEfficiency * systemEfficiency;

        // ---- State Machine ----
        state def OperatingState;

        state machine trompeOperation : OperatingState {
            state Idle;
            state Priming;
            state Operating;
            state Degraded;
            state Shutdown;

            transition idleToPriming
                from Idle to Priming
                when (externalWaterIn.water != null);
            transition primingToOperating
                from Priming to Operating
                when (shaft.mixtureIn.mixture.pressure > 101325.0);
            transition operatingToDegraded
                from Operating to Degraded
                when (vessel.operatingPressure < theoreticalOutputPressure * 0.8);
            transition degradedToOperating
                from Degraded to Operating
                when (vessel.operatingPressure >= theoreticalOutputPressure * 0.9);
            transition operatingToShutdown
                from Operating to Shutdown
                when (externalWaterIn.water == null);
            transition degradedToShutdown
                from Degraded to Shutdown
                when (externalWaterIn.water == null);
            transition shutdownToIdle
                from Shutdown to Idle
                when (true);

            entry Idle { /* system ready, no water flow */ }
            entry Priming { /* water begins filling intake and shaft */ }
            entry Operating { /* steady-state compression and separation */ }
            entry Degraded { /* reduced performance, monitoring */ }
            entry Shutdown { /* graceful stop, drain residual water */ }
        }
    }

    // ---- Requirements ----
    requirement def PassiveOperationRequirement {
        subject trompe : Trompe;
        objective {
            doc "The Trompe shall compress air without moving parts or external electricity."
        }
        assume trompe.sourceHead >= 3.0;
    }

    requirement def CompressionPressureRequirement {
        subject trompe : Trompe;
        attribute minimumOutputPressure : PressureValue = 600000.0;
        objective {
            doc "The Trompe shall deliver compressed air at a pressure of at least 600 kPa."
        }
        require trompe.theoreticalOutputPressure >= minimumOutputPressure;
    }

    requirement def ContinuousOperationRequirement {
        subject trompe : Trompe;
        objective {
            doc "The Trompe shall operate continuously given a constant water source."
        }
        require trompe.trompeOperating == Operating;
    }

    requirement def ShaftDepthRequirement {
        subject shaft : VerticalShaft;
        attribute minimumDepth : DepthValue = 40.0;
        objective {
            doc "The vertical shaft shall be at least 40 m deep to achieve target pressure."
        }
        require shaft.shaftDepth >= minimumDepth;
    }

    requirement def SeparationEfficiencyRequirement {
        subject vessel : SeparationVessel;
        attribute minimumEfficiency : EfficiencyValue = 0.9;
        objective {
            doc "The separation vessel shall separate at least 90% of compressed air from water."
        }
        require vessel.separationEfficiency >= minimumEfficiency;
    }

    requirement def TailraceDischargeRequirement {
        subject tailrace : TailraceOutlet;
        objective {
            doc "The tailrace shall discharge water at the same rate as the intake to maintain steady state."
        }
        require tailrace.dischargeFlowRate == 2.0;
    }

    // ---- Verification ----
    verification def VerifyOutputPressure {
        subject trompe : Trompe;
        objective {
            doc "Measure output pressure and confirm it meets CompressionPressureRequirement."
        }
    }

    verification def VerifyContinuousOperation {
        subject trompe : Trompe;
        objective {
            doc "Run system for 72 hours and confirm continuous compressed air delivery."
        }
    }
}
