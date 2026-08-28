package EndFaceMechanicalSealModel {
    import ScalarValues::*;

    // ---- Units ----
    unit 'Pa';
    unit 'K';
    unit 'rad/s';
    unit 'N';
    unit 'm';
    unit 'm3/s';
    unit 'N/m';

    // ---- Value Types ----
    value def Pressure :> Real { unit 'Pa'; }
    value def Temperature :> Real { unit 'K'; }
    value def RotationalSpeed :> Real { unit 'rad/s'; }
    value def Force :> Real { unit 'N'; }
    value def Length :> Real { unit 'm'; }
    value def VolumetricFlowRate :> Real { unit 'm3/s'; }
    value def SpringRate :> Real { unit 'N/m'; }

    // ---- Item Definitions ----
    item def ProcessFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute hazardLevel : Real;
        attribute viscosity : Real;
    }

    item def BarrierFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute cleanlinessClass : Integer;
        attribute viscosity : Real;
    }

    item def LeakageFlow {
        attribute flowRate : VolumetricFlowRate;
        attribute source : String;
    }

    // ---- Port Definitions ----
    port def ProcessFluidPort {
        in item processFluid : ProcessFluid;
    }

    port def BarrierFluidPort {
        in item barrierFluid : BarrierFluid;
    }

    port def ShaftInterfacePort {
        in attribute shaftSpeed : RotationalSpeed;
        in attribute shaftTorque : Real;
    }

    port def HousingMountPort {
        in attribute mountingForce : Force;
    }

    port def AtmosphericPort {
        out item leakageToAtmosphere : LeakageFlow;
    }

    // ---- Part Definitions ----
    part def StationaryRing {
        attribute material : String = "Silicon Carbide";
        attribute surfaceRoughness : Length = 0.05e-6 ['m'];
        attribute flatness : Length = 0.3e-6 ['m'];
        attribute outerDiameter : Length;
        attribute innerDiameter : Length;
        port housingMount : HousingMountPort;
    }

    part def RotatingRing {
        attribute material : String = "Carbon Graphite";
        attribute surfaceRoughness : Length = 0.05e-6 ['m'];
        attribute flatness : Length = 0.3e-6 ['m'];
        attribute outerDiameter : Length;
        attribute innerDiameter : Length;
        port shaftInterface : ShaftInterfacePort;
    }

    part def SpringMechanism {
        attribute springForce : Force = 150 ['N'];
        attribute springConstant : SpringRate = 5000 ['N/m'];
        attribute compression : Length;
    }

    part def SecondarySeal {
        attribute sealType : String = "O-ring";
        attribute material : String = "FKM";
        attribute sealDiameter : Length;
        attribute crossSectionDiameter : Length;
    }

    part def BarrierFluidChamber {
        attribute volume : Real = 0.001;
        attribute barrierPressure : Pressure;
        attribute maxOperatingPressure : Pressure = 5e6 ['Pa'];
        port barrierFluidPort : BarrierFluidPort;
    }

    part def SealHousing {
        attribute material : String = "Stainless Steel 316L";
        attribute maxPressure : Pressure = 10e6 ['Pa'];
        part chamber : BarrierFluidChamber;
        port processFluidPort : ProcessFluidPort;
        port atmosphericPort : AtmosphericPort;
    }

    part def MonitoringSystem {
        attribute measuredLeakageRate : VolumetricFlowRate;
        attribute measuredFaceTemperature : Temperature;
        attribute vibrationLevel : Real;
        attribute healthStatus : String = "healthy";
        attribute wearIndicator : Real = 0.0;
    }

    part def FluidFilm {
        attribute thickness : Length;
        attribute pressure : Pressure;
        attribute minThickness : Length = 0.1e-6 ['m'];
        attribute maxThickness : Length = 3.0e-6 ['m'];
    }

    // ---- Connection Definitions ----
    connection def MechanicalForceConnection {
        end source : SpringMechanism;
        end target : RotatingRing;
        attribute transmittedForce : Force;
    }

    connection def FaceContactConnection {
        end stationary : StationaryRing;
        end rotating : RotatingRing;
        attribute contactPressure : Pressure;
    }

    connection def FluidFilmConnection {
        end stationary : StationaryRing;
        end rotating : RotatingRing;
        attribute film : FluidFilm;
    }

    // ---- Action Definitions ----
    action def MaintainFaceContact {
        in springForce : Force;
        in fluidPressure : Pressure;
        in barrierPressure : Pressure;
        out closingForce : Force;
        perform {
            compute closingForce = springForce + fluidPressure * 0.001 + barrierPressure * 0.001;
        }
    }

    action def GenerateHydrodynamicFilm {
        in shaftSpeed : RotationalSpeed;
        in barrierPressure : Pressure;
        in closingForce : Force;
        out filmThickness : Length;
        perform {
            compute filmThickness = (shaftSpeed * barrierPressure * 1e-12) / closingForce;
        }
    }

    action def MonitorSealHealth {
        in leakage : VolumetricFlowRate;
        in temperature : Temperature;
        in vibration : Real;
        out healthStatus : String;
        out wearIndicator : Real;
        perform {
            if leakage > 1e-6 ['m3/s'] or temperature > 350 ['K'] then {
                assign healthStatus = "degraded";
            } elif leakage > 1e-4 ['m3/s'] or temperature > 400 ['K'] then {
                assign healthStatus = "failed";
            } else {
                assign healthStatus = "healthy";
            }
        }
    }

    action def RegulateBarrierPressure {
        in processPressure : Pressure;
        inout barrierPressure : Pressure;
        perform {
            if barrierPressure < processPressure + 20000 ['Pa'] then {
                assign barrierPressure = processPressure + 20000 ['Pa'];
            }
        }
    }

    // ---- State Machine Definition ----
    state def SealLifecycle {
        entry; then idle;

        state idle {
            entry assign self.monitor.healthStatus = "idle";
        }

        state startup {
            entry assign self.monitor.healthStatus = "starting";
            do action startupAction {
                perform MaintainFaceContact(
                    self.spring.springForce,
                    self.processPort.processFluid.pressure,
                    self.housing.chamber.barrierPressure
                );
                perform RegulateBarrierPressure(
                    self.processPort.processFluid.pressure,
                    self.housing.chamber.barrierPressure
                );
            }
        }

        state normalOperation {
            entry assign self.monitor.healthStatus = "operational";
            do action normalOperationAction {
                perform GenerateHydrodynamicFilm(
                    self.shaftPort.shaftSpeed,
                    self.housing.chamber.barrierPressure,
                    self.spring.springForce
                );
                perform MonitorSealHealth(
                    self.monitor.measuredLeakageRate,
                    self.monitor.measuredFaceTemperature,
                    self.monitor.vibrationLevel
                );
            }
        }

        state degraded {
            entry assign self.monitor.healthStatus = "degraded";
            do action degradedAction {
                perform MonitorSealHealth(
                    self.monitor.measuredLeakageRate,
                    self.monitor.measuredFaceTemperature,
                    self.monitor.vibrationLevel
                );
            }
        }

        state failed {
            entry assign self.monitor.healthStatus = "failed";
        }

        state shutdown {
            entry assign self.monitor.healthStatus = "shutting_down";
        }

        transition idle_to_startup
            first idle
            to startup
            when self.shaftPort.shaftSpeed > 0 ['rad/s'];

        transition startup_to_normal
            first startup
            to normalOperation
            when self.monitor.measuredFaceTemperature < 350 ['K']
            and self.monitor.measuredLeakageRate < 1e-6 ['m3/s'];

        transition normal_to_degraded
            first normalOperation
            to degraded
            when self.monitor.measuredLeakageRate > 1e-6 ['m3/s']
            or self.monitor.measuredFaceTemperature > 350 ['K'];

        transition degraded_to_failed
            first degraded
            to failed
            when self.monitor.measuredLeakageRate > 1e-4 ['m3/s']
            or self.monitor.measuredFaceTemperature > 400 ['K'];

        transition normal_to_shutdown
            first normalOperation
            to shutdown
            when self.shaftPort.shaftSpeed == 0 ['rad/s'];

        transition degraded_to_shutdown
            first degraded
            to shutdown
            when self.shaftPort.shaftSpeed == 0 ['rad/s'];

        transition shutdown_to_idle
            first shutdown
            to idle
            when self.shaftPort.shaftSpeed == 0 ['rad/s']
            and self.monitor.healthStatus != "failed";

        transition failed_to_idle
            first failed
            to idle
            when self.monitor.healthStatus == "replaced";
    }

    // ---- Requirement Definitions ----
    requirement def SealLeakageRequirement {
        subject seal : EndFaceSeal;
        requirement {
            doc /* The seal leakage rate shall not exceed 1e-6 m3/s during normal operation. */
            constraint { seal.monitor.measuredLeakageRate <= 1e-6 ['m3/s'] }
        }
    }

    requirement def BarrierPressureRequirement {
        subject seal : EndFaceSeal;
        requirement {
            doc /* Barrier fluid pressure shall be at least 0.2 bar above process fluid pressure. */
            constraint { seal.housing.chamber.barrierPressure >= seal.processPort.processFluid.pressure + 20000 ['Pa'] }
        }
    }

    requirement def FaceFlatnessRequirement {
        subject seal : EndFaceSeal;
        requirement {
            doc /* Seal face flatness shall be within 0.6 micrometers for both rings. */
            constraint { seal.stationaryRing.flatness <= 0.6e-6 ['m'] }
            constraint { seal.rotatingRing.flatness <= 0.6e-6 ['m'] }
        }
    }

    requirement def FaceTemperatureRequirement {
        subject seal : EndFaceSeal;
        requirement {
            doc /* Face temperature shall not exceed 350 K during normal operation. */
            constraint { seal.monitor.measuredFaceTemperature <= 350 ['K'] }
        }
    }

    requirement def FilmThicknessRequirement {
        subject seal : EndFaceSeal;
        requirement {
            doc /* Hydrodynamic film thickness shall be between 0.1 and 3.0 micrometers. */
            constraint { seal.fluidFilm.thickness >= 0.1e-6 ['m'] }
            constraint { seal.fluidFilm.thickness <= 3.0e-6 ['m'] }
        }
    }

    requirement def SpringForceRequirement {
        subject seal : EndFaceSeal;
        requirement {
            doc /* Spring mechanism shall apply a minimum closing force of 100 N. */
            constraint { seal.spring.springForce >= 100 ['N'] }
        }
    }

    requirement def SecondarySealRequirement {
        subject seal : EndFaceSeal;
        requirement {
            doc /* At least two secondary O-ring seals shall be present to prevent secondary leakage paths. */
            constraint { seal.secondarySeals->size() >= 2 }
        }
    }

    requirement def HousingMaterialRequirement {
        subject seal : EndFaceSeal;
        requirement {
            doc /* Seal housing shall be constructed from stainless steel. */
            constraint { seal.housing.material == "Stainless Steel 316L" }
        }
    }

    // ---- Main Seal Assembly ----
    part def EndFaceSeal {
        port processPort : ProcessFluidPort;
        port barrierPort : BarrierFluidPort;
        port shaftPort : ShaftInterfacePort;

        part stationaryRing : StationaryRing {
            attribute outerDiameter = 0.08 ['m'];
            attribute innerDiameter = 0.06 ['m'];
        }

        part rotatingRing : RotatingRing {
            attribute outerDiameter = 0.08 ['m'];
            attribute innerDiameter = 0.06 ['m'];
        }

        part spring : SpringMechanism {
            attribute compression = 0.03 ['m'];
        }

        part secondarySeals : SecondarySeal[4] {
            attribute sealDiameter = 0.06 ['m'];
            attribute crossSectionDiameter = 0.003 ['m'];
        }

        part housing : SealHousing {
            part chamber : BarrierFluidChamber {
                attribute barrierPressure = 3e6 ['Pa'];
            }
        }

        part monitor : MonitoringSystem {
            attribute measuredLeakageRate = 0.0 ['m3/s'];
            attribute measuredFaceTemperature = 293.15 ['K'];
            attribute vibrationLevel = 0.0;
        }

        part fluidFilm : FluidFilm {
            attribute thickness = 1.0e-6 ['m'];
            attribute pressure = 2.5e6 ['Pa'];
        }

        // Connections
        connection springForceConn : MechanicalForceConnection
            connect spring to rotatingRing;

        connection faceContactConn : FaceContactConnection
            connect stationaryRing to rotatingRing;

        connection fluidFilmConn : FluidFilmConnection
            connect stationaryRing to rotatingRing;

        connection housingMountConn
            connect stationaryRing.housingMount to housing;

        connection shaftDriveConn
            connect rotatingRing.shaftInterface to shaftPort;

        connection processFluidConn
            connect processPort to housing.processFluidPort;

        connection barrierFluidConn
            connect barrierPort to housing.chamber.barrierFluidPort;

        // Exhibit state machine
        exhibit state lifecycle : SealLifecycle;

        // Satisfy requirements
        satisfy leakageReq : SealLeakageRequirement by self;
        satisfy barrierReq : BarrierPressureRequirement by self;
        satisfy flatnessReq : FaceFlatnessRequirement by self;
        satisfy tempReq : FaceTemperatureRequirement by self;
        satisfy filmReq : FilmThicknessRequirement by self;
        satisfy springReq : SpringForceRequirement by self;
        satisfy secondarySealReq : SecondarySealRequirement by self;
        satisfy housingReq : HousingMaterialRequirement by self;
    }
}
