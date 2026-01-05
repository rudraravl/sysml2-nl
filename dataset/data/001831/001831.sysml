package PistonActuationSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def PistonStroke :> LengthValue;
    attribute def PistonArea :> AreaValue;
    attribute def FluidPressure :> PressureValue;
    attribute def ActuationForce :> ForceValue;
    attribute def PistonSpeed :> SpeedValue;
    
    item def HydraulicFluid {
        attribute pressure : FluidPressure;
        attribute flowRate : VolumeFlowValue;
        attribute temperature : TemperatureValue;
    }
    
    attribute def ExtendCommand;
    attribute def RetractCommand;
    attribute def HoldCommand;
    
    port def FluidPort {
        in item fluid : HydraulicFluid;
        attribute pressure : FluidPressure;
    }
    
    port def MechanicalOutputPort {
        out force : ActuationForce;
        out displacement : PistonStroke;
        out velocity : PistonSpeed;
    }
    
    part def PistonHead {
        attribute effectiveArea : PistonArea;
        attribute mass : MassValue;
        attribute currentPosition : PistonStroke;
        port hydraulicFace : FluidPort;
    }
    
    part def CylinderBody {
        attribute boreDiameter : LengthValue;
        attribute strokeLength : PistonStroke;
        attribute wallThickness : LengthValue;
        port chamberPort : FluidPort;
        port exhaustPort : FluidPort;
    }
    
    part def PistonRod {
        attribute rodDiameter : LengthValue;
        attribute rodLength : LengthValue;
        attribute rodMass : MassValue;
        port outputConnection : MechanicalOutputPort;
    }
    
    part def PistonSeal {
        attribute sealType : String;
        attribute maxPressureRating : FluidPressure;
        attribute frictionCoefficient : Real;
    }
    
    enumeration ValveState {
        extend;
        retract;
        neutral;
    }
    
    part def FluidValve {
        attribute valvePosition : ValveState;
        port supplyPort : FluidPort;
        port workPort : FluidPort;
        port returnPort : FluidPort;
    }
    
    part def HydraulicPump {
        attribute ratedPressure : FluidPressure;
        attribute maxFlowRate : VolumeFlowValue;
        attribute efficiency : Real;
        port pressureOutput : FluidPort;
        port returnInput : FluidPort;
    }
    
    action def CalculateActuationForce {
        in fluidPressure : FluidPressure;
        in pistonArea : PistonArea;
        out outputForce : ActuationForce;
    }
    
    action def ExtendPiston {
        in supplyPressure : FluidPressure;
        in pistonArea : PistonArea;
        in currentPosition : PistonStroke;
        in maxStroke : PistonStroke;
        out extensionForce : ActuationForce;
        out newPosition : PistonStroke;
        out extensionVelocity : PistonSpeed;
        
        perform action calculateForce : CalculateActuationForce {
            in fluidPressure = supplyPressure;
            in pistonArea = pistonArea;
            out outputForce;
        }
        then assign extensionForce := calculateForce.outputForce;
    }
    
    action def RetractPiston {
        in returnPressure : FluidPressure;
        in pistonArea : PistonArea;
        in currentPosition : PistonStroke;
        out retractionForce : ActuationForce;
        out newPosition : PistonStroke;
        out retractionVelocity : PistonSpeed;
        
        perform action calculateForce : CalculateActuationForce {
            in fluidPressure = returnPressure;
            in pistonArea = pistonArea;
            out outputForce;
        }
        then assign retractionForce := calculateForce.outputForce;
    }
    
    action def HoldPosition {
        in currentPosition : PistonStroke;
        in currentForce : ActuationForce;
        out heldPosition : PistonStroke;
        out heldForce : ActuationForce;
    }
    
    state def PistonOperationStateMachine {
        attribute position : PistonStroke;
        attribute maxStroke : PistonStroke;
        
        entry; then idle;
        
        state idle;
        
        state extending {
            entry action extend : ExtendPiston;
        }
        
        state fullyExtended;
        
        state retracting {
            entry action retract : RetractPiston;
        }
        
        state holding {
            do action hold : HoldPosition;
        }
        
        transition idleToExtending
            first idle
            accept extendCmd : ExtendCommand
            then extending;
        
        transition extendingToFullyExtended
            first extending
            if position >= maxStroke
            then fullyExtended;
        
        transition fullyExtendedToRetracting
            first fullyExtended
            accept retractCmd : RetractCommand
            then retracting;
        
        transition retractingToIdle
            first retracting
            if position <= 0.0[m]
            then idle;
        
        transition extendingToHolding
            first extending
            accept holdCmd : HoldCommand
            then holding;
        
        transition retractingToHolding
            first retracting
            accept holdCmd : HoldCommand
            then holding;
        
        transition holdingToExtending
            first holding
            accept extendCmd : ExtendCommand
            then extending;
        
        transition holdingToRetracting
            first holding
            accept retractCmd : RetractCommand
            then retracting;
    }
    
    action def OperatePistonCycle {
        in commandExtend : ExtendCommand;
        in commandRetract : RetractCommand;
        in commandHold : HoldCommand;
        in systemPressure : FluidPressure;
        in pistonEffectiveArea : PistonArea;
        in strokeLimit : PistonStroke;
        out mechanicalForce : ActuationForce;
        out mechanicalDisplacement : PistonStroke;
        out mechanicalVelocity : PistonSpeed;
        
        private attribute currentPosition : PistonStroke := 0.0[m];
        private attribute currentForce : ActuationForce := 0.0[N];
        
        loop {
            accept extCmd : ExtendCommand;
            then perform action extending : ExtendPiston {
                in supplyPressure = systemPressure;
                in pistonArea = pistonEffectiveArea;
                in currentPosition = currentPosition;
                in maxStroke = strokeLimit;
                out extensionForce;
                out newPosition;
                out extensionVelocity;
            }
            then assign currentPosition := extending.newPosition;
            then assign currentForce := extending.extensionForce;
            then assign mechanicalForce := currentForce;
            then assign mechanicalDisplacement := currentPosition;
            then assign mechanicalVelocity := extending.extensionVelocity;
            
            then accept retCmd : RetractCommand;
            then perform action retracting : RetractPiston {
                in returnPressure = systemPressure;
                in pistonArea = pistonEffectiveArea;
                in currentPosition = currentPosition;
                out retractionForce;
                out newPosition;
                out retractionVelocity;
            }
            then assign currentPosition := retracting.newPosition;
            then assign currentForce := retracting.retractionForce;
            then assign mechanicalForce := currentForce;
            then assign mechanicalDisplacement := currentPosition;
            then assign mechanicalVelocity := retracting.retractionVelocity;
            
            then accept hldCmd : HoldCommand;
            then perform action holding : HoldPosition {
                in currentPosition = currentPosition;
                in currentForce = currentForce;
                out heldPosition;
                out heldForce;
            }
            then assign mechanicalForce := holding.heldForce;
            then assign mechanicalDisplacement := holding.heldPosition;
        }
    }
    
    part def PistonActuator {
        attribute operatingPressure : FluidPressure;
        attribute maximumStroke : PistonStroke;
        attribute outputForce : ActuationForce;
        
        port fluidSupply : FluidPort;
        port fluidReturn : FluidPort;
        port mechanicalOutput : MechanicalOutputPort;
        
        part pistonHead : PistonHead {
            attribute effectiveArea = 0.00785[m^2];
            attribute mass = 2.5[kg];
        }
        
        part cylinderBody : CylinderBody {
            attribute boreDiameter = 100.0[mm];
            attribute strokeLength = 500.0[mm];
            attribute wallThickness = 10.0[mm];
        }
        
        part pistonRod : PistonRod {
            attribute rodDiameter = 40.0[mm];
            attribute rodLength = 600.0[mm];
            attribute rodMass = 1.8[kg];
        }
        
        part primarySeal : PistonSeal {
            attribute sealType = "O-ring";
            attribute maxPressureRating = 25000000.0[Pa];
            attribute frictionCoefficient = 0.15;
        }
        
        part secondarySeal : PistonSeal {
            attribute sealType = "Wiper";
            attribute maxPressureRating = 20000000.0[Pa];
            attribute frictionCoefficient = 0.10;
        }
        
        connect pistonHead.hydraulicFace to cylinderBody.chamberPort;
        connect pistonRod.outputConnection to mechanicalOutput;
        connect fluidSupply to cylinderBody.chamberPort;
        connect fluidReturn to cylinderBody.exhaustPort;
        
        exhibit behavior : PistonOperationStateMachine {
            attribute position = pistonHead.currentPosition;
            attribute maxStroke = cylinderBody.strokeLength;
        }
    }
    
    part def HydraulicPowerUnit {
        attribute systemPressure : FluidPressure;
        attribute systemFlowRate : VolumeFlowValue;
        
        port pressureSupply : FluidPort;
        port tankReturn : FluidPort;
        
        part pump : HydraulicPump {
            attribute ratedPressure = 20000000.0[Pa];
            attribute maxFlowRate = 0.001[m^3/s];
            attribute efficiency = 0.85;
        }
        
        connect pump.pressureOutput to pressureSupply;
        connect pump.returnInput to tankReturn;
    }
    
    part def PistonSystem {
        port systemSupply : FluidPort;
        port systemReturn : FluidPort;
        port loadOutput : MechanicalOutputPort;
        
        part powerUnit : HydraulicPowerUnit {
            attribute systemPressure = 20000000.0[Pa];
            attribute systemFlowRate = 0.0008[m^3/s];
        }
        
        part controlValve : FluidValve {
            attribute valvePosition = ValveState::neutral;
        }
        
        part actuator : PistonActuator {
            attribute operatingPressure = 20000000.0[Pa];
            attribute maximumStroke = 500.0[mm];
        }
        
        connect powerUnit.pressureSupply to controlValve.supplyPort;
        connect controlValve.workPort to actuator.fluidSupply;
        connect actuator.fluidReturn to controlValve.returnPort;
        connect controlValve.returnPort to powerUnit.tankReturn;
        connect actuator.mechanicalOutput to loadOutput;
        
        perform action operation : OperatePistonCycle {
            in systemPressure = powerUnit.systemPressure;
            in pistonEffectiveArea = actuator.pistonHead.effectiveArea;
            in strokeLimit = actuator.maximumStroke;
            out mechanicalForce;
            out mechanicalDisplacement;
            out mechanicalVelocity;
        }
    }
    
    requirement <'REQ-001'> primaryFunctionRequirement {
        doc /* The piston system shall convert hydraulic fluid pressure into controlled 
                linear mechanical force and motion to perform work on external loads. */
        
        subject pistonSystem : PistonSystem;
        
        require constraint forceGeneration {
            doc /* The system must generate sufficient output force based on fluid pressure 
                    and piston effective area. */
        }
        
        require constraint linearMotion {
            doc /* The piston must provide controlled linear displacement within the 
                    specified stroke length. */
        }
    }
    
    requirement <'REQ-002'> performanceRequirement {
        doc /* The piston actuator shall deliver minimum force output at rated pressure. */
        
        subject actuator : PistonActuator;
        
        require constraint minimumForce {
            actuator.outputForce >= 157000.0[N]
        }
        
        require constraint strokeRange {
            actuator.maximumStroke >= 500.0[mm]
        }
    }
    
    requirement <'REQ-003'> safetyRequirement {
        doc /* The piston system shall operate safely within pressure and temperature limits. */
        
        subject pistonSystem : PistonSystem;
        
        require constraint pressureLimit {
            pistonSystem.powerUnit.systemPressure <= 25000000.0[Pa]
        }
        
        require constraint sealIntegrity {
            doc /* Seals must maintain integrity at maximum operating pressure. */
        }
    }
    
    part pistonSystemInstance : PistonSystem;
    
    satisfy primaryFunctionRequirement by pistonSystemInstance;
    satisfy performanceRequirement by pistonSystemInstance.actuator;
    satisfy safetyRequirement by pistonSystemInstance;
}
