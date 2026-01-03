package SuzukiFrameVehicleSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FrameIdentifier {
        attribute manufacturer : String;
        attribute modelDesignation : String;
        attribute productionYear : Integer;
        attribute serialNumber : String;
    }
    
    attribute def StiffnessValue :> Real;
    attribute def LoadCapacityValue :> MassValue;
    attribute def TorqueValue :> Real;
    attribute def AngleValue :> Real;
    
    item def RiderCommand {
        attribute throttlePosition : Real;
        attribute brakeInput : Real;
        attribute steeringAngle : AngleValue;
        attribute clutchEngagement : Real;
    }
    
    item def PowerOutput {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : Real;
    }
    
    item def LoadDistribution {
        attribute frontLoad : MassValue;
        attribute rearLoad : MassValue;
        attribute lateralLoad : MassValue;
    }
    
    item def StructuralResponse {
        attribute deflection : LengthValue;
        attribute stress : Real;
        attribute vibrationLevel : Real;
    }
    
    port def StructuralMountPort {
        in attribute appliedLoad : MassValue;
        out attribute mountReaction : StructuralResponse;
    }
    
    port def PowertrainMountPort {
        in item powerInput : PowerOutput;
        out attribute vibrationDamping : Real;
    }
    
    port def SuspensionAttachmentPort {
        in attribute suspensionForce : Real;
        out attribute frameDeflection : LengthValue;
    }
    
    port def RiderInterfacePort {
        in item command : RiderCommand;
        out attribute feedbackForce : Real;
    }
    
    part def SuzukiFrame {
        attribute frameId : FrameIdentifier;
        attribute frameMaterial : String;
        attribute frameMass : MassValue;
        attribute torsionalStiffness : StiffnessValue;
        attribute maxLoadCapacity : LoadCapacityValue;
        attribute wheelbase : LengthValue;
        
        port riderInterface : RiderInterfacePort;
        port engineMount : PowertrainMountPort;
        port frontSuspensionMount : SuspensionAttachmentPort;
        port rearSuspensionMount : SuspensionAttachmentPort;
        port frontLoadPoint : StructuralMountPort;
        port rearLoadPoint : StructuralMountPort;
    }
    
    part def Powertrain {
        attribute displacement : Real;
        attribute maxTorque : TorqueValue;
        attribute maxPower : Real;
        attribute operatingRPM : Real;
        
        port outputShaft : PowertrainMountPort;
    }
    
    part def FrontSuspension {
        attribute forkTravel : LengthValue;
        attribute springRate : Real;
        attribute damperCoefficient : Real;
        
        port frameAttachment : SuspensionAttachmentPort;
        port wheelAttachment : StructuralMountPort;
    }
    
    part def RearSuspension {
        attribute swingarmLength : LengthValue;
        attribute shockTravel : LengthValue;
        attribute springPreload : Real;
        
        port frameAttachment : SuspensionAttachmentPort;
        port wheelAttachment : StructuralMountPort;
    }
    
    part def Wheel {
        attribute diameter : LengthValue;
        attribute width : LengthValue;
        attribute rotationalInertia : Real;
        
        port axleMount : StructuralMountPort;
    }
    
    part def RiderStation {
        attribute seatHeight : LengthValue;
        attribute handlebarPosition : LengthValue;
        attribute footpegPosition : LengthValue;
        
        port controlInterface : RiderInterfacePort;
        port seatLoad : StructuralMountPort;
    }
    
    part def FuelSystem {
        attribute tankCapacity : VolumeValue;
        attribute currentFuelLevel : VolumeValue;
        attribute fuelType : String;
    }
    
    action def DistributeLoad {
        in totalLoad : MassValue;
        in centerOfGravityPosition : LengthValue;
        out frontDistribution : MassValue;
        out rearDistribution : MassValue;
    }
    
    action def TransmitPower {
        in engineTorque : TorqueValue;
        in gearRatio : Real;
        out wheelTorque : TorqueValue;
    }
    
    action def AbsorbVibration {
        in inputVibration : Real;
        in dampingFactor : Real;
        out transmittedVibration : Real;
    }
    
    action def MaintainStability {
        in riderInput : RiderCommand;
        in loadCondition : LoadDistribution;
        out stabilityFactor : Real;
    }
    
    action def TransportRider {
        first start;
        then merge operationalLoop;
        
        then action receiveRiderInput {
            in commands : RiderCommand;
            out processedCommands : RiderCommand;
        }
        
        then action assessLoadCondition : DistributeLoad {
            in totalLoad;
            in centerOfGravityPosition;
            out frontDistribution;
            out rearDistribution;
        }
        
        then decide;
            if assessLoadCondition.frontDistribution.num > 0.0 then manageFrontLoad;
            if assessLoadCondition.rearDistribution.num > 0.0 then manageRearLoad;
        
        action manageFrontLoad {
            then action transferToFrontSuspension;
        }
        
        action manageRearLoad {
            then action transferToRearSuspension;
        }
        
        then merge loadManaged;
        
        then action deliverPower : TransmitPower {
            in engineTorque;
            in gearRatio = 3.5;
            out wheelTorque;
        }
        
        then action dampVibrations : AbsorbVibration {
            in inputVibration;
            in dampingFactor = 0.65;
            out transmittedVibration;
        }
        
        then action ensureStability : MaintainStability {
            in riderInput;
            in loadCondition;
            out stabilityFactor;
        }
        
        then decide;
            if ensureStability.stabilityFactor >= 0.8 then continueTransport;
            if ensureStability.stabilityFactor < 0.8 then adjustOperation;
        
        action continueTransport;
        then operationalLoop;
        
        action adjustOperation {
            then action recalibrateSystem;
        }
        then operationalLoop;
    }
    
    state def VehicleOperationalStates {
        entry; then parked;
        
        state parked;
        transition parked_to_starting
            first parked
            accept startCommand : RiderCommand
            then starting;
        
        state starting {
            entry; then initializeSystems;
            
            state initializeSystems;
            transition init_to_ready
                first initializeSystems
                then ready;
            
            state ready;
        }
        
        transition starting_to_moving
            first starting
            accept accelerateCommand : RiderCommand
            then moving;
        
        state moving {
            entry; then accelerating;
            
            state accelerating;
            transition accel_to_cruising
                first accelerating
                then cruising;
            
            state cruising;
            transition cruise_to_accel
                first cruising
                then accelerating;
            
            transition cruise_to_decel
                first cruising
                then decelerating;
            
            state decelerating;
            transition decel_to_cruise
                first decelerating
                then cruising;
        }
        
        transition moving_to_stopping
            first moving
            accept stopCommand : RiderCommand
            then stopping;
        
        state stopping;
        transition stopping_to_parked
            first stopping
            then parked;
    }
    
    part suzukiVehicle : SuzukiFrame {
        attribute :>> frameId {
            attribute :>> manufacturer = "Suzuki Motor Corporation";
            attribute :>> modelDesignation = "GSX-S";
            attribute :>> productionYear = 2024;
            attribute :>> serialNumber = "SZ-GSX-2024-7891";
        }
        attribute :>> frameMaterial = "High-Tensile Steel Alloy";
        attribute :>> frameMass = 14.2 [SI::kg];
        attribute :>> torsionalStiffness = 92000.0;
        attribute :>> maxLoadCapacity = 195.0 [SI::kg];
        attribute :>> wheelbase = 1450.0 [SI::mm];
        
        perform action primaryFunction : TransportRider;
        
        exhibit state operationalBehavior : VehicleOperationalStates;
        
        part engine : Powertrain {
            attribute :>> displacement = 749.0;
            attribute :>> maxTorque = 81.0;
            attribute :>> maxPower = 85.0;
            attribute :>> operatingRPM = 11500.0;
        }
        
        part frontSusp : FrontSuspension {
            attribute :>> forkTravel = 120.0 [SI::mm];
            attribute :>> springRate = 9.2;
            attribute :>> damperCoefficient = 1.8;
        }
        
        part rearSusp : RearSuspension {
            attribute :>> swingarmLength = 580.0 [SI::mm];
            attribute :>> shockTravel = 130.0 [SI::mm];
            attribute :>> springPreload = 5.5;
        }
        
        part frontWheel : Wheel {
            attribute :>> diameter = 432.0 [SI::mm];
            attribute :>> width = 120.0 [SI::mm];
            attribute :>> rotationalInertia = 2.1;
        }
        
        part rearWheel : Wheel {
            attribute :>> diameter = 457.0 [SI::mm];
            attribute :>> width = 180.0 [SI::mm];
            attribute :>> rotationalInertia = 2.8;
        }
        
        part riderPosition : RiderStation {
            attribute :>> seatHeight = 810.0 [SI::mm];
            attribute :>> handlebarPosition = 950.0 [SI::mm];
            attribute :>> footpegPosition = 380.0 [SI::mm];
        }
        
        part fuel : FuelSystem {
            attribute :>> tankCapacity = 19.0 [SI::'L'];
            attribute :>> currentFuelLevel = 15.0 [SI::'L'];
            attribute :>> fuelType = "Unleaded Gasoline 95 RON";
        }
        
        connection engineToFrame : PowertrainConnection
            connect engine.outputShaft to engineMount;
        
        connection riderToFrame : RiderConnection
            connect riderPosition.controlInterface to riderInterface;
        
        connection riderLoadToFrame : LoadConnection
            connect riderPosition.seatLoad to rearLoadPoint;
        
        connection frontSuspToFrame : SuspensionConnection
            connect frontSusp.frameAttachment to frontSuspensionMount;
        
        connection rearSuspToFrame : SuspensionConnection
            connect rearSusp.frameAttachment to rearSuspensionMount;
        
        connection frontWheelToSusp : WheelConnection
            connect frontWheel.axleMount to frontSusp.wheelAttachment;
        
        connection rearWheelToSusp : WheelConnection
            connect rearWheel.axleMount to rearSusp.wheelAttachment;
    }
    
    connection def PowertrainConnection {
        end source : PowertrainMountPort;
        end target : PowertrainMountPort;
    }
    
    connection def RiderConnection {
        end source : RiderInterfacePort;
        end target : RiderInterfacePort;
    }
    
    connection def LoadConnection {
        end source : StructuralMountPort;
        end target : StructuralMountPort;
    }
    
    connection def SuspensionConnection {
        end source : SuspensionAttachmentPort;
        end target : SuspensionAttachmentPort;
    }
    
    connection def WheelConnection {
        end source : StructuralMountPort;
        end target : StructuralMountPort;
    }
    
    requirement <'REQ-SF-001'> structuralIntegrity {
        doc /* The Suzuki frame shall maintain structural integrity under 
             * maximum rated load conditions with adequate safety margin.
            */
        subject frame : SuzukiFrame;
        
        assert constraint {
            frame.maxLoadCapacity.num >= 190.0
        }
    }
    
    requirement <'REQ-SF-002'> massConstraint {
        doc /* The frame mass shall not exceed 15 kg to optimize 
             * power-to-weight ratio and handling performance.
            */
        subject frame :>> suzukiVehicle;
        
        assert constraint {
            frame.frameMass.num <= 15.0
        }
    }
    
    requirement <'REQ-SF-003'> stiffnessRequirement {
        doc /* The frame shall provide sufficient torsional stiffness 
             * to ensure precise handling and stability.
            */
        subject frame :>> suzukiVehicle;
        
        assert constraint {
            frame.torsionalStiffness >= 90000.0
        }
    }
    
    requirement <'REQ-SF-004'> loadDistributionRequirement {
        doc /* The frame shall distribute operational loads between 
             * front and rear suspension mounting points to maintain 
             * balanced handling characteristics.
            */
        subject frame : SuzukiFrame;
    }
    
    requirement <'REQ-SF-005'> vibrationIsolation {
        doc /* The frame shall provide adequate vibration isolation 
             * between powertrain and rider interface to ensure 
             * comfort during operation.
            */
        subject frame : SuzukiFrame;
    }
    
    requirement <'REQ-SF-100'> primaryTransportFunction {
        doc /* The Suzuki frame-based vehicle system shall provide safe, 
             * stable, and efficient transportation of a rider by 
             * integrating powertrain, suspension, and control systems 
             * into a unified structural platform that maintains 
             * integrity under all operational conditions.
            */
        subject vehicle :>> suzukiVehicle;
    }
    
    satisfy primaryTransportFunction by suzukiVehicle;
}
