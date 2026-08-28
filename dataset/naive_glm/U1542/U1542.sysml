package ATHLETE {
    import ScalarValues::*;
    
    // --- Units and Value Types ---
    unit m;
    unit deg;
    unit Nm;
    unit mps;
    unit W;
    unit kg;
    
    attribute def Length :> Real { unit = m; }
    attribute def Angle :> Real { unit = deg; }
    attribute def Torque :> Real { unit = Nm; }
    attribute def Speed :> Real { unit = mps; }
    attribute def Power :> Real { unit = W; }
    attribute def Mass :> Real { unit = kg; }
    
    // --- Enums ---
    enum def MobilityMode {
        rolling;
        walking;
        climbing;
        anchored;
    }
    
    // --- Items ---
    item def TerrainData {
        attribute surfaceRoughness : Length;
        attribute slope : Angle;
        attribute obstacleHeight : Length;
    }
    
    item def PathPlan {
        attribute targetMode : MobilityMode;
        attribute targetVelocity : Speed;
    }
    
    item def JointCommand {
        attribute shoulderAngle : Angle;
        attribute elbowAngle : Angle;
        attribute wristAngle : Angle;
        attribute wheelAngle : Angle;
        attribute shoulderTorque : Torque;
        attribute elbowTorque : Torque;
        attribute wristTorque : Torque;
        attribute wheelTorque : Torque;
    }
    
    item def PowerFlow {
        attribute power : Power;
    }
    
    item def Cargo {
        attribute mass : Mass;
    }
    
    // --- Ports ---
    port def TerrainOutPort { out data : TerrainData; }
    port def TerrainInPort { in data : TerrainData; }
    port def PathOutPort { out plan : PathPlan; }
    port def PathInPort { in plan : PathPlan; }
    port def CmdOutPort { out cmd : JointCommand; }
    port def CmdInPort { in cmd : JointCommand; }
    port def PowerOutPort { out power : PowerFlow; }
    port def PowerInPort { in power : PowerFlow; }
    
    // --- Requirements ---
    requirement def RoverSpec {
        doc << ATHLETE Rover Requirements >>
        requirement adaptToTerrain {
            doc << The rover shall autonomously adapt mobility mode to terrain. >>
        }
        requirement carryPayload {
            doc << The rover shall carry and secure an optional payload. >>
            attribute maxPayloadMass : Mass = 5000 [kg];
        }
        requirement stablePlatform {
            doc << The rover shall provide a stable stationary platform when anchored. >>
        }
    }
    
    // --- Parts ---
    part def Wheel {
        port powerIn : PowerInPort;
        attribute steerAngle : Angle;
        attribute driveTorque : Torque;
        attribute isPowered : Boolean = true;
        attribute isSteerable : Boolean = true;
        
        action def drive {
            in power : Power;
            in torque : Torque;
            in angle : Angle;
        }
    }
    
    part def LimbJoint {
        port powerIn : PowerInPort;
        attribute jointAngle : Angle;
        attribute jointTorque : Torque;
        
        action def actuate {
            in power : Power;
            in torque : Torque;
            in angle : Angle;
        }
    }
    
    part def Limb {
        port powerIn : PowerInPort;
        port cmdIn : CmdInPort;
        
        part shoulder : LimbJoint;
        part elbow : LimbJoint;
        part wrist : LimbJoint;
        part wheel : Wheel;
        
        connection powerIn to shoulder.powerIn;
        connection shoulder.powerIn to elbow.powerIn;
        connection elbow.powerIn to wrist.powerIn;
        connection wrist.powerIn to wheel.powerIn;
        
        action def executeCommand {
            in cmd : JointCommand;
        }
    }
    
    part def TerrainSensorSuite {
        port terrainOut : TerrainOutPort;
        attribute scanRange : Length = 10 [m];
        
        action def scan {
            out data : TerrainData;
        }
    }
    
    part def NavigationSystem {
        port terrainIn : TerrainInPort;
        port pathOut : PathOutPort;
        
        action def planPath {
            in terrain : TerrainData;
            out plan : PathPlan;
        }
    }
    
    part def MobilityController {
        port pathIn : PathInPort;
        port cmdOut : CmdOutPort;
        attribute currentMode : MobilityMode;
        
        state machine MobilityBehavior {
            state rolling;
            state walking;
            state climbing;
            state anchored;
            
            transition initial to rolling;
            transition rolling to walking when pathIn.plan.targetMode == MobilityMode::walking;
            transition walking to rolling when pathIn.plan.targetMode == MobilityMode::rolling;
            transition walking to climbing when pathIn.plan.targetMode == MobilityMode::climbing;
            transition climbing to walking when pathIn.plan.targetMode == MobilityMode::walking;
            transition rolling to anchored when pathIn.plan.targetMode == MobilityMode::anchored;
            transition walking to anchored when pathIn.plan.targetMode == MobilityMode::anchored;
            transition climbing to anchored when pathIn.plan.targetMode == MobilityMode::anchored;
            transition anchored to rolling when pathIn.plan.targetMode == MobilityMode::rolling;
        }
        
        action def generateCommands {
            in plan : PathPlan;
            out cmd : JointCommand;
        }
    }
    
    part def PowerSource {
        port powerOut : PowerOutPort;
        attribute maxOutput : Power = 1000 [W];
        attribute currentCapacity : Power;
        
        action def generatePower {
            out power : PowerFlow;
        }
    }
    
    part def PayloadInterface {
        part payload : Cargo[0..1];
        attribute isSecured : Boolean = false;
        
        action def securePayload {
            in cargo : Cargo;
        }
    }
    
    part def ATHLETE {
        satisfy RoverSpec;
        
        attribute numLimbs : Integer = 6;
        
        part powerSource : PowerSource;
        part terrainSensors : TerrainSensorSuite;
        part navSystem : NavigationSystem;
        part mobilityController : MobilityController;
        part payloadInterface : PayloadInterface;
        part limbs : Limb[6];
        
        connection powerSource.powerOut to limbs.powerIn;
        connection terrainSensors.terrainOut to navSystem.terrainIn;
        connection navSystem.pathOut to mobilityController.pathIn;
        connection mobilityController.cmdOut to limbs.cmdIn;
    }
}
