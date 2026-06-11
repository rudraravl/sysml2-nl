package EndFaceMechanicalSealSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def Pressure :> Real {
        unit = "Pa";
    }

    attribute def Temperature :> Real {
        unit = "K";
    }

    attribute def RotationalSpeed :> Real {
        unit = "rpm";
    }

    attribute def LeakRate :> Real {
        unit = "mL/h";
    }

    attribute def Force :> Real {
        unit = "N";
    }

    attribute def Length :> Real {
        unit = "m";
    }

    attribute def SurfaceRoughness :> Real {
        unit = "um";
    }

    attribute def FlowRate :> Real {
        unit = "L/min";
    }

    attribute def Torque :> Real {
        unit = "N*m";
    }

    item def ProcessFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute viscosity : Real;
        attribute vaporPressure : Pressure;
        attribute corrosive : Boolean;
        attribute containsSolids : Boolean;
    }

    item def BarrierFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
        attribute compatibleWithProcessFluid : Boolean;
    }

    item def Heat {
        attribute heatFlowRate : Real;
        attribute sourceTemperature : Temperature;
    }

    item def MechanicalPower {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }

    item def Leakage {
        attribute leakRate : LeakRate;
        attribute phase : String;
        attribute routedToDrain : Boolean;
    }

    port def FluidPort {
        inout fluid : ProcessFluid;
    }

    port def BarrierFluidPort {
        inout barrierFluid : BarrierFluid;
    }

    port def LeakagePort {
        out leakage : Leakage;
    }

    port def ThermalPort {
        out heat : Heat;
    }

    port def ShaftInterfacePort {
        in power : MechanicalPower;
        attribute shaftDiameter : Length;
        attribute axialRunout : Length;
        attribute radialRunout : Length;
    }

    part def SealFace {
        attribute outsideDiameter : Length;
        attribute insideDiameter : Length;
        attribute faceWidth : Length;
        attribute flatness : Length;
        attribute roughness : SurfaceRoughness;
        attribute material : String;
        attribute hardness : Real;
        attribute thermalConductivity : Real;
        attribute wearAllowance : Length;

        port processSide : FluidPort;
        port filmSide : FluidPort;
        port thermal : ThermalPort;
    }

    part def RotatingFace :> SealFace {
        attribute rotatesWithShaft : Boolean = true;
    }

    part def StationaryFace :> SealFace {
        attribute lockedToHousing : Boolean = true;
    }

    part def SecondarySeal {
        attribute type : String;
        attribute material : String;
        attribute compression : Length;
        attribute maxTemperature : Temperature;
        attribute chemicalCompatibility : Boolean;

        port processSide : FluidPort;
    }

    part def SpringPack {
        attribute numberOfSprings : Integer;
        attribute springRate : Real;
        attribute preloadForce : Force;
        attribute workingForce : Force;
        attribute corrosionResistant : Boolean;

        port forceOutput;
    }

    part def GlandPlate {
        attribute material : String;
        attribute boltCount : Integer;
        attribute boltCircleDiameter : Length;
        attribute gasketCompression : Length;

        port processSide : FluidPort;
        port leakageOut : LeakagePort;
        port flushIn : BarrierFluidPort;
        port quenchIn : BarrierFluidPort;
    }

    part def ShaftSleeve {
        attribute material : String;
        attribute sleeveDiameter : Length;
        attribute sleeveLength : Length;
        attribute surfaceFinish : SurfaceRoughness;
        attribute lockedToShaft : Boolean;

        port shaftInterface : ShaftInterfacePort;
    }

    part def SealChamber {
        attribute chamberPressure : Pressure;
        attribute chamberTemperature : Temperature;
        attribute allowablePressure : Pressure;
        attribute allowableTemperature : Temperature;

        port processIn : FluidPort;
        port processOut : FluidPort;
    }

    part def EndFaceMechanicalSeal {
        attribute ratedPressure : Pressure;
        attribute ratedTemperature : Temperature;
        attribute ratedSpeed : RotationalSpeed;
        attribute allowableLeakRate : LeakRate;
        attribute minimumFilmThickness : Length;
        attribute balancedDesign : Boolean;
        attribute primaryFunction : String =
            "Maintain a controlled sealing interface between a rotating shaft and stationary housing by pressing two precision end faces together, allowing only a thin lubricating film and limiting process-fluid leakage to a safe, specified rate.";

        port shaft : ShaftInterfacePort;
        port processIn : FluidPort;
        port processOut : FluidPort;
        port barrierIn : BarrierFluidPort;
        port leakageOut : LeakagePort;
        port heatOut : ThermalPort;

        part chamber : SealChamber;
        part sleeve : ShaftSleeve;
        part rotatingFace : RotatingFace;
        part stationaryFace : StationaryFace;
        part dynamicSecondarySeal : SecondarySeal {
            attribute type = "O-ring";
            attribute material = "FKM";
        }
        part staticSecondarySeal : SecondarySeal {
            attribute type = "Gasket";
            attribute material = "Graphite-filled PTFE";
        }
        part springs : SpringPack;
        part gland : GlandPlate;

        connect processIn to chamber.processIn;
        connect chamber.processOut to processOut;
        connect chamber.processIn to rotatingFace.processSide;
        connect chamber.processIn to stationaryFace.processSide;
        connect rotatingFace.filmSide to stationaryFace.filmSide;
        connect shaft to sleeve.shaftInterface;
        connect gland.processSide to chamber.processIn;
        connect gland.flushIn to barrierIn;
        connect gland.leakageOut to leakageOut;
        connect rotatingFace.thermal to heatOut;
        connect stationaryFace.thermal to heatOut;
        connect dynamicSecondarySeal.processSide to chamber.processIn;
        connect staticSecondarySeal.processSide to gland.processSide;

        action def EstablishSealFilm {
            in processFluid : ProcessFluid;
            in faceClosingForce : Force;
            in speed : RotationalSpeed;
            out stableFilmThickness : Length;
            out generatedHeat : Heat;
        }

        action def LimitLeakage {
            in processFluid : ProcessFluid;
            in stableFilmThickness : Length;
            out leakage : Leakage;
        }

        action def RemoveHeat {
            in generatedHeat : Heat;
            in barrierFluid : BarrierFluid;
            out rejectedHeat : Heat;
        }

        action sealOperation {
            first start;
            then establishFilm : EstablishSealFilm {
                in processFluid = chamber.processIn.fluid;
                in faceClosingForce = springs.workingForce;
                in speed = shaft.power.speed;
            }
            then limitLeakage : LimitLeakage {
                in processFluid = chamber.processIn.fluid;
                in stableFilmThickness = establishFilm.stableFilmThickness;
            }
            then rejectHeat : RemoveHeat {
                in generatedHeat = establishFilm.generatedHeat;
                in barrierFluid = barrierIn.barrierFluid;
            }
            then done;
        }

        state def SealOperatingState {
            state Installed;
            state Pressurized;
            state Running;
            state ControlledLeakage;
            state Alarm;
            state Shutdown;

            transition initial then Installed;

            transition Installed_to_Pressurized
                first Installed
                accept PressureApplied
                then Pressurized;

            transition Pressurized_to_Running
                first Pressurized
                accept ShaftRotationStarted
                then Running;

            transition Running_to_ControlledLeakage
                first Running
                if chamber.chamberPressure <= ratedPressure and
                   chamber.chamberTemperature <= ratedTemperature and
                   shaft.power.speed <= ratedSpeed
                then ControlledLeakage;

            transition ControlledLeakage_to_Alarm
                first ControlledLeakage
                if leakageOut.leakage.leakRate > allowableLeakRate or
                   shaft.axialRunout > 0.00005 or
                   shaft.radialRunout > 0.00005
                then Alarm;

            transition Alarm_to_Shutdown
                first Alarm
                accept OperatorStop
                then Shutdown;

            transition ControlledLeakage_to_Shutdown
                first ControlledLeakage
                accept PlannedStop
                then Shutdown;
        }

        exhibit stateMachine : SealOperatingState;
        perform action sealOperation;
    }

    requirement def SealPrimaryFunctionRequirement {
        subject seal : EndFaceMechanicalSeal;
        require constraint {
            seal.allowableLeakRate <= 10.0
        }
        doc /* The seal shall restrict process-fluid leakage along the rotating shaft to a controlled value while permitting shaft rotation. */
    }

    requirement def FaceContactRequirement {
        subject seal : EndFaceMechanicalSeal;
        require constraint {
            seal.minimumFilmThickness >= 0.000001 and
            seal.minimumFilmThickness <= 0.00001
        }
        doc /* The seal shall maintain a lubricating fluid film between the rotating and stationary end faces during normal operation. */
    }

    requirement def PressureCapabilityRequirement {
        subject seal : EndFaceMechanicalSeal;
        require constraint {
            seal.ratedPressure >= seal.chamber.chamberPressure
        }
        doc /* The seal pressure rating shall be no less than the maximum process pressure in the seal chamber. */
    }

    requirement def TemperatureCapabilityRequirement {
        subject seal : EndFaceMechanicalSeal;
        require constraint {
            seal.ratedTemperature >= seal.chamber.chamberTemperature
        }
        doc /* The seal temperature rating shall be no less than the maximum process temperature in the seal chamber. */
    }

    requirement def ShaftCompatibilityRequirement {
        subject seal : EndFaceMechanicalSeal;
        require constraint {
            seal.shaft.shaftDiameter == seal.sleeve.sleeveDiameter
        }
        doc /* The shaft sleeve shall match the specified shaft interface diameter and transmit rotation to the rotating face. */
    }

    requirement def HeatRemovalRequirement {
        subject seal : EndFaceMechanicalSeal;
        require constraint {
            seal.barrierIn.barrierFluid.flowRate >= 1.0
        }
        doc /* The seal shall provide a flush or barrier-fluid path capable of removing frictional heat generated at the end faces. */
    }

    part mechanicalSealAssembly : EndFaceMechanicalSeal {
        attribute ratedPressure = 2500000.0;
        attribute ratedTemperature = 473.15;
        attribute ratedSpeed = 3600.0;
        attribute allowableLeakRate = 5.0;
        attribute minimumFilmThickness = 0.000003;
        attribute balancedDesign = true;

        part chamber {
            attribute chamberPressure = 1800000.0;
            attribute chamberTemperature = 353.15;
            attribute allowablePressure = 2500000.0;
            attribute allowableTemperature = 473.15;
        }

        part sleeve {
            attribute material = "316 stainless steel";
            attribute sleeveDiameter = 0.05;
            attribute sleeveLength = 0.16;
            attribute surfaceFinish = 0.4;
            attribute lockedToShaft = true;
        }

        part rotatingFace {
            attribute outsideDiameter = 0.085;
            attribute insideDiameter = 0.052;
            attribute faceWidth = 0.012;
            attribute flatness = 0.0000006;
            attribute roughness = 0.1;
            attribute material = "silicon carbide";
            attribute hardness = 2500.0;
            attribute thermalConductivity = 120.0;
            attribute wearAllowance = 0.003;
        }

        part stationaryFace {
            attribute outsideDiameter = 0.085;
            attribute insideDiameter = 0.052;
            attribute faceWidth = 0.012;
            attribute flatness = 0.0000006;
            attribute roughness = 0.1;
            attribute material = "carbon graphite";
            attribute hardness = 800.0;
            attribute thermalConductivity = 25.0;
            attribute wearAllowance = 0.004;
        }

        part dynamicSecondarySeal {
            attribute compression = 0.0012;
            attribute maxTemperature = 473.15;
            attribute chemicalCompatibility = true;
        }

        part staticSecondarySeal {
            attribute compression = 0.0015;
            attribute maxTemperature = 523.15;
            attribute chemicalCompatibility = true;
        }

        part springs {
            attribute numberOfSprings = 8;
            attribute springRate = 15000.0;
            attribute preloadForce = 420.0;
            attribute workingForce = 560.0;
            attribute corrosionResistant = true;
        }

        part gland {
            attribute material = "316 stainless steel";
            attribute boltCount = 4;
            attribute boltCircleDiameter = 0.125;
            attribute gasketCompression = 0.0015;
        }
    }

    satisfy SealPrimaryFunctionRequirement by mechanicalSealAssembly;
    satisfy FaceContactRequirement by mechanicalSealAssembly;
    satisfy PressureCapabilityRequirement by mechanicalSealAssembly;
    satisfy TemperatureCapabilityRequirement by mechanicalSealAssembly;
    satisfy ShaftCompatibilityRequirement by mechanicalSealAssembly;
    satisfy HeatRemovalRequirement by mechanicalSealAssembly;
}