package PlungerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    doc /* 
     * This model describes a plunger-based hydraulic system that converts 
     * mechanical force into fluid pressure and displacement through reciprocating motion.
     */

    attribute def PressureValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def ForceValue :> Real;
    attribute def VelocityValue :> Real;

    item def Fluid {
        attribute volume : VolumeValue;
        attribute pressure : PressureValue;
    }

    port def FluidPort {
        inout fluid : Fluid;
    }

    port def ForcePort {
        in appliedForce : ForceValue;
    }

    part def PlungerHead {
        attribute diameter : LengthValue;
        attribute surfaceArea : AreaValue;
    }

    part def PlungerShaft {
        attribute length : LengthValue;
        attribute diameter : LengthValue;
    }

    part def Seal {
        attribute compressionRatio : Real;
        attribute leakageRate : Real;
    }

    part def Cylinder {
        attribute innerDiameter : LengthValue;
        attribute strokeLength : LengthValue;
        attribute maxVolume : VolumeValue;
        port fluidInterface : FluidPort;
    }

    part def Plunger {
        attribute position : LengthValue;
        attribute velocity : VelocityValue;
        attribute appliedForce : ForceValue;
        attribute maxStroke : LengthValue;
        attribute generatedPressure : PressureValue;

        part head : PlungerHead {
            attribute :>> diameter : LengthValue = 50.0 [mm];
            attribute :>> surfaceArea : AreaValue = 1963.5 [mm^2];
        }

        part shaft : PlungerShaft {
            attribute :>> length : LengthValue = 200.0 [mm];
            attribute :>> diameter : LengthValue = 40.0 [mm];
        }

        part seal : Seal {
            attribute :>> compressionRatio : Real = 0.2;
            attribute :>> leakageRate : Real = 0.002;
        }

        port forceInput : ForcePort;

        assert constraint pressureCalculation {
            generatedPressure == appliedForce / head.surfaceArea
        }

        assert constraint strokeLimit {
            position <= maxStroke
        }
    }

    action def MonitorPosition {
        in currentPosition : LengthValue;
        in targetPosition : LengthValue;
        out positionError : LengthValue;
    }

    action def ApplyForce {
        in targetForce : ForceValue;
        out actualForce : ForceValue;
    }

    action def DisplaceFluid {
        in displacement : LengthValue;
        in plungerArea : AreaValue;
        out volumeDisplaced : VolumeValue;
    }

    action def GeneratePressure {
        in force : ForceValue;
        in area : AreaValue;
        out pressure : PressureValue;
    }

    state def PlungerOperationStates {
        entry; then idle;

        state idle {
            doc /* Plunger is at rest, no force applied. */
        }
        transition idle_to_extending
            first idle
            accept at 0
            then extending;

        state extending {
            doc /* Plunger is moving forward, displacing fluid. */
        }
        transition extending_to_extended
            first extending
            if position >= maxStroke
            then extended;

        state extended {
            doc /* Plunger has reached maximum stroke. */
        }
        transition extended_to_retracting
            first extended
            accept at 0
            then retracting;

        state retracting {
            doc /* Plunger is moving backward, drawing fluid. */
        }
        transition retracting_to_idle
            first retracting
            if position <= 0 [mm]
            then idle;

        in position : LengthValue;
        in maxStroke : LengthValue;
    }

    action def PlungerOperationCycle {
        first start;
        then action monitorInitial : MonitorPosition {
            in currentPosition : LengthValue;
            in targetPosition : LengthValue;
            out positionError : LengthValue;
        }
        then decide;
            if monitorInitial.positionError > 0 [mm] then extendAction;
            if monitorInitial.positionError <= 0 [mm] then retractAction;

        action extendAction {
            first action applyForce : ApplyForce {
                in targetForce : ForceValue;
                out actualForce : ForceValue;
            }
            then action displaceFluid : DisplaceFluid {
                in displacement : LengthValue;
                in plungerArea : AreaValue;
                out volumeDisplaced : VolumeValue;
            }
            then action generatePressure : GeneratePressure {
                in force = applyForce.actualForce;
                in area : AreaValue;
                out pressure : PressureValue;
            }
        }
        then merge checkPosition;

        action retractAction {
            first action applyRetractForce : ApplyForce {
                in targetForce : ForceValue;
                out actualForce : ForceValue;
            }
            then action displaceReverse : DisplaceFluid {
                in displacement : LengthValue;
                in plungerArea : AreaValue;
                out volumeDisplaced : VolumeValue;
            }
        }
        then checkPosition;

        merge checkPosition;
        then action monitorFinal : MonitorPosition {
            in currentPosition : LengthValue;
            in targetPosition : LengthValue;
            out positionError : LengthValue;
        }
        then decide;
            if monitorFinal.positionError == 0 [mm] then complete;
            else monitorInitial;

        action complete;
        then done;
    }

    part def PlungerSystem {
        attribute operatingPressure : PressureValue;
        attribute maxPressure : PressureValue;
        attribute cycleFrequency : Real;
        attribute totalVolume : VolumeValue;

        part plunger : Plunger {
            attribute :>> position : LengthValue = 0.0 [mm];
            attribute :>> velocity : VelocityValue = 0.0 [mm/s];
            attribute :>> appliedForce : ForceValue = 500.0 [N];
            attribute :>> maxStroke : LengthValue = 150.0 [mm];
            attribute :>> generatedPressure : PressureValue;
        }

        part cylinder : Cylinder {
            attribute :>> innerDiameter : LengthValue = 50.5 [mm];
            attribute :>> strokeLength : LengthValue = 150.0 [mm];
            attribute :>> maxVolume : VolumeValue = 300000.0 [mm^3];
        }

        item workingFluid : Fluid {
            attribute :>> volume : VolumeValue;
            attribute :>> pressure : PressureValue;
        }

        connection plungerToCylinder connect plunger to cylinder;
        connection fluidConnection connect cylinder.fluidInterface to workingFluid;

        assert constraint volumeCalculation {
            totalVolume == plunger.head.surfaceArea * plunger.position
        }

        assert constraint pressureLimit {
            operatingPressure <= maxPressure
        }

        perform action operate : PlungerOperationCycle;
    }

    requirement <'REQ-001'> primaryFunction {
        doc /* The plunger system shall convert linear mechanical force 
             * into hydraulic pressure and fluid displacement through 
             * reciprocating motion within a sealed cylinder.
             */
        subject system : PlungerSystem;
    }

    requirement <'REQ-002'> pressureGeneration {
        doc /* The system shall generate hydraulic pressure equal to 
             * the applied force divided by the plunger head surface area.
             */
        subject system : PlungerSystem;
        assert constraint {
            system.plunger.generatedPressure == 
                system.plunger.appliedForce / system.plunger.head.surfaceArea
        }
    }

    requirement <'REQ-003'> volumeDisplacement {
        doc /* The system shall displace fluid volume equal to the 
             * plunger head area multiplied by the stroke displacement.
             */
        subject system : PlungerSystem;
        assert constraint {
            system.totalVolume == 
                system.plunger.head.surfaceArea * system.plunger.position
        }
    }

    requirement <'REQ-004'> sealIntegrity {
        doc /* The plunger seal shall maintain leakage rate below 
             * 0.5% of displaced volume per cycle.
             */
        subject seal :>> PlungerSystem::plunger.seal;
        assert constraint {
            seal.leakageRate <= 0.005
        }
    }

    requirement <'REQ-005'> strokeLimit {
        doc /* The plunger position shall not exceed the maximum 
             * stroke length of 150 mm.
             */
        subject plunger :>> PlungerSystem::plunger;
        assert constraint {
            plunger.position <= 150.0 [mm]
        }
    }

    requirement <'REQ-006'> pressureLimit {
        doc /* The operating pressure shall not exceed the maximum 
             * rated pressure of 250 bar.
             */
        subject system : PlungerSystem;
        assert constraint {
            system.operatingPressure <= system.maxPressure &&
            system.maxPressure <= 250.0
        }
    }

    part plungerSystemInstance : PlungerSystem {
        attribute :>> operatingPressure : PressureValue;
        attribute :>> maxPressure : PressureValue = 250.0;
        attribute :>> cycleFrequency : Real = 30.0;
        attribute :>> totalVolume : VolumeValue;
    }

    satisfy primaryFunction by plungerSystemInstance;
    satisfy pressureGeneration by plungerSystemInstance;
    satisfy volumeDisplacement by plungerSystemInstance;
    satisfy sealIntegrity by plungerSystemInstance.plunger.seal;
    satisfy strokeLimit by plungerSystemInstance.plunger;
    satisfy pressureLimit by plungerSystemInstance;
}
