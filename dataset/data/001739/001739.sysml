package 'AlHassanCrankConnectingRodSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    doc /* This model describes a water-raising machine (saqiya) based on the pioneering 
         work of historian Ahmad Y. al-Hassan, who documented the earliest known use of 
         the crank-and-connecting-rod mechanism in Islamic engineering during the 9th century.
         
         The system's primary function is to convert continuous rotary motion from an 
         animal-driven horizontal wheel into reciprocating linear motion of water-lifting 
         pistons, enabling efficient irrigation by raising water from rivers to elevated 
         aqueducts. This represents a fundamental mechanical innovation that predates 
         European use of the crank mechanism by several centuries. */

    attribute def RotationalSpeed :> Real;
    attribute def LinearDisplacement :> Real;
    attribute def CrankAngle :> Real;
    
    attribute def Torque :> ISQ::torque;
    attribute def Force :> ISQ::force;
    attribute def FlowRate :> ISQ::volumeFlowRate;
    attribute def AngularVelocity :> ISQ::angularVelocity;
    
    item def Water {
        attribute volume : ISQ::VolumeValue;
        attribute mass : ISQ::MassValue;
    }
    
    port def RotaryPowerPort {
        in inputTorque : Torque;
        in rotationalSpeed : AngularVelocity;
    }
    
    port def LinearMotionPort {
        out force : Force;
        out displacement : ISQ::LengthValue;
    }
    
    port def WaterFlowPort {
        inout waterFlow : Water;
        attribute flowRate : FlowRate;
    }
    
    part def AnimalDriveUnit {
        attribute nominalTorque : Torque;
        attribute operatingSpeed : AngularVelocity;
        port driveOutput : RotaryPowerPort;
    }
    
    part def HorizontalWheel {
        attribute wheelDiameter : ISQ::LengthValue;
        attribute wheelMass : ISQ::MassValue;
        port axleInput : RotaryPowerPort;
        port crankOutput : RotaryPowerPort;
    }
    
    part def CrankShaft {
        attribute crankRadius : ISQ::LengthValue;
        attribute crankAngle : CrankAngle;
        port rotaryInput : RotaryPowerPort;
        port crankPin;
    }
    
    part def ConnectingRod {
        attribute rodLength : ISQ::LengthValue;
        attribute rodMass : ISQ::MassValue;
        port crankEnd;
        port pistonEnd;
    }
    
    part def PistonAssembly {
        attribute pistonDiameter : ISQ::LengthValue;
        attribute pistonStroke : ISQ::LengthValue;
        attribute pistonPosition : LinearDisplacement;
        port rodConnection;
        port waterIntake : WaterFlowPort;
        port waterDischarge : WaterFlowPort;
    }
    
    part def WaterSource {
        attribute sourceLevel : ISQ::LengthValue;
        port outlet : WaterFlowPort;
    }
    
    part def ElevatedAqueduct {
        attribute aqueductLevel : ISQ::LengthValue;
        port inlet : WaterFlowPort;
    }
    
    action def ApplyAnimalPower {
        in command : Boolean;
        out driveTorque : Torque;
        out driveSpeed : AngularVelocity;
    }
    
    action def TransmitRotaryMotion {
        in inputTorque : Torque;
        in inputSpeed : AngularVelocity;
        out outputTorque : Torque;
        out outputSpeed : AngularVelocity;
        out crankAngle : CrankAngle;
    }
    
    action def ConvertToLinearMotion {
        in crankAngle : CrankAngle;
        in crankRadius : ISQ::LengthValue;
        in rodLength : ISQ::LengthValue;
        out pistonDisplacement : ISQ::LengthValue;
        out pistonForce : Force;
    }
    
    action def LiftWater {
        in pistonDisplacement : ISQ::LengthValue;
        in pistonForce : Force;
        in sourceWater : Water;
        out elevatedWater : Water;
        out actualFlowRate : FlowRate;
    }
    
    attribute def StartMachine;
    attribute def StopMachine;
    attribute def MaintenanceRequired;
    attribute def MaintenanceComplete;
    
    state def MachineOperatingStates {
        in attribute systemActive : Boolean;
        in attribute driveSpeed : AngularVelocity;
        in attribute minimumOperatingSpeed : AngularVelocity;
        
        entry; then idle;
        
        state idle {
            entry assign systemActive := false;
        }
        
        transition idle_to_starting
            first idle
            accept startCmd : StartMachine
            then starting;
        
        state starting {
            entry assign systemActive := true;
            do action initializeDrive : ApplyAnimalPower;
        }
        
        transition starting_to_pumping
            first starting
            if driveSpeed > minimumOperatingSpeed
            then pumping;
        
        state pumping {
            do action transmitPower : TransmitRotaryMotion;
            do action convertMotion : ConvertToLinearMotion;
            do action raiseWater : LiftWater;
        }
        
        state maintenance {
            entry assign systemActive := false;
        }
        
        transition pumping_to_maintenance
            first pumping
            accept maintReq : MaintenanceRequired
            then maintenance;
        
        transition pumping_to_stopping
            first pumping
            accept stopCmd : StopMachine
            then stopping;
        
        state stopping {
            entry assign systemActive := false;
        }
        
        transition stopping_to_idle
            first stopping
            if driveSpeed <= 0.0
            then idle;
        
        transition maintenance_to_idle
            first maintenance
            accept maintDone : MaintenanceComplete
            then idle;
    }
    
    action def OperateWaterRaisingMachine {
        in attribute sourceWaterSupply : Water[*];
        out attribute totalWaterLifted : ISQ::VolumeValue;
        
        attribute systemActive : Boolean;
        attribute driveSpeed : AngularVelocity;
        attribute minimumOperatingSpeed : AngularVelocity;
        attribute currentCrankAngle : CrankAngle;
        attribute accumulatedVolume : ISQ::VolumeValue;
        
        first start;
        then merge continuousOperation;
        
        then action activateDrive : ApplyAnimalPower {
            in command = systemActive;
            out driveTorque : Torque;
            out driveSpeed : AngularVelocity;
        }
        
        then action rotateCrank : TransmitRotaryMotion {
            in inputTorque = activateDrive.driveTorque;
            in inputSpeed = activateDrive.driveSpeed;
            out outputTorque : Torque;
            out outputSpeed : AngularVelocity;
            out crankAngle : CrankAngle;
        }
        
        then action drivePiston : ConvertToLinearMotion {
            in crankAngle = rotateCrank.crankAngle;
            in crankRadius : ISQ::LengthValue;
            in rodLength : ISQ::LengthValue;
            out pistonDisplacement : ISQ::LengthValue;
            out pistonForce : Force;
        }
        
        then action pumpWater : LiftWater {
            in pistonDisplacement = drivePiston.pistonDisplacement;
            in pistonForce = drivePiston.pistonForce;
            in sourceWater : Water;
            out elevatedWater : Water;
            out actualFlowRate : FlowRate;
        }
        
        then assign currentCrankAngle := rotateCrank.crankAngle;
        then assign accumulatedVolume := accumulatedVolume + pumpWater.elevatedWater.volume;
        
        then decide;
            if systemActive and driveSpeed > 0.0 then continuousOperation;
            if not systemActive or driveSpeed <= 0.0 then shutdown;
        
        action shutdown {
            out finalVolume : ISQ::VolumeValue;
        }
        
        then assign totalWaterLifted := accumulatedVolume;
        then done;
    }
    
    part def SaqiyaWaterRaisingMachine;
    
    part saqiyaSystem : SaqiyaWaterRaisingMachine {
        attribute liftHeight : ISQ::LengthValue;
        attribute targetFlowRate : FlowRate;
        attribute crankRadiusValue : ISQ::LengthValue;
        attribute connectingRodLengthValue : ISQ::LengthValue;
        
        perform action operateMachine : OperateWaterRaisingMachine;
        
        part animalDrive : AnimalDriveUnit {
            attribute nominalTorque = 300.0 [SI::N*SI::m];
            attribute operatingSpeed = 0.5 [SI::rad/SI::s];
            perform operateMachine.activateDrive;
        }
        
        part horizontalWheel : HorizontalWheel {
            attribute wheelDiameter = 2.0 [SI::m];
            attribute wheelMass = 150.0 [SI::kg];
            perform operateMachine.rotateCrank;
        }
        
        part crankshaft : CrankShaft {
            attribute crankRadius = 0.15 [SI::m];
            attribute crankAngle : CrankAngle;
        }
        
        part connectingRod : ConnectingRod {
            attribute rodLength = 0.8 [SI::m];
            attribute rodMass = 5.0 [SI::kg];
        }
        
        part piston : PistonAssembly {
            attribute pistonDiameter = 0.12 [SI::m];
            attribute pistonStroke = 0.25 [SI::m];
            attribute pistonPosition : LinearDisplacement;
            perform operateMachine.drivePiston;
            perform operateMachine.pumpWater;
        }
        
        part riverSource : WaterSource {
            attribute sourceLevel = 0.0 [SI::m];
        }
        
        part aqueduct : ElevatedAqueduct {
            attribute aqueductLevel = 3.5 [SI::m];
        }
        
        connect animalDrive.driveOutput to horizontalWheel.axleInput;
        connect horizontalWheel.crankOutput to crankshaft.rotaryInput;
        connect crankshaft.crankPin to connectingRod.crankEnd;
        connect connectingRod.pistonEnd to piston.rodConnection;
        connect riverSource.outlet to piston.waterIntake;
        connect piston.waterDischarge to aqueduct.inlet;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The saqiya machine shall convert continuous rotary motion into 
             reciprocating linear motion to raise water from a lower source to 
             an elevated destination for irrigation purposes. */
    }
    
    requirement def MechanicalInnovationRequirement {
        doc /* The system shall employ a crank-and-connecting-rod mechanism as 
             documented by Ahmad Y. al-Hassan, representing the earliest known 
             application of this fundamental mechanical principle. */
    }
    
    requirement def WaterLiftingCapacityRequirement {
        doc /* The machine shall lift water to a minimum height of 3 meters above 
             the source level. */
        
        attribute minimumLiftHeight : ISQ::LengthValue = 3.0 [SI::m];
        
        require constraint liftHeightConstraint {
            saqiyaSystem.liftHeight >= minimumLiftHeight
        }
    }
    
    requirement def FlowRateRequirement {
        doc /* The system shall deliver a minimum flow rate of 15 cubic meters per 
             hour during continuous operation. */
        
        attribute minimumFlowRate : FlowRate = 15.0 [SI::m^3/SI::h];
        
        require constraint flowRateConstraint {
            saqiyaSystem.targetFlowRate >= minimumFlowRate
        }
    }
    
    requirement def ReliabilityRequirement {
        doc /* The machine shall operate continuously for a minimum of 8 hours 
             without mechanical failure or intervention. */
        
        attribute minimumOperatingDuration : ISQ::TimeValue = 8.0 [SI::h];
    }
    
    requirement def EfficiencyRequirement {
        doc /* The mechanical efficiency of the crank-connecting rod conversion 
             shall exceed 75% to minimize energy loss. */
        
        attribute minimumEfficiency : Real = 0.75;
    }
    
    requirement saqiyaSystemRequirements {
        doc /* Overall requirements for the al-Hassan water-raising machine system 
             ensuring functional performance, historical accuracy, and operational 
             reliability. */
        
        subject machine : SaqiyaWaterRaisingMachine;
        
        require reqPrimaryFunction : PrimaryFunctionRequirement;
        require reqMechanicalInnovation : MechanicalInnovationRequirement;
        require reqLiftingCapacity : WaterLiftingCapacityRequirement;
        require reqFlowRate : FlowRateRequirement;
        require reqReliability : ReliabilityRequirement;
        require reqEfficiency : EfficiencyRequirement;
        
        assume constraint adequateAnimalPower {
            doc /* Sufficient and consistent animal power is available to drive 
                 the horizontal wheel. */
        }
        
        assume constraint continuousWaterSupply {
            doc /* The water source provides continuous supply at the intake level. */
        }
        
        assume constraint structuralIntegrity {
            doc /* All mechanical components maintain structural integrity under 
                 operational loads. */
        }
    }
}
