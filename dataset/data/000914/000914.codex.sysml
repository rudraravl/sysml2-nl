package NoriaSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    item def Water {
        attribute temperature : Real;
        attribute suspendedSolidsConcentration : Real;
    }

    item def MechanicalPower {
        attribute torque : Real;
        attribute angularVelocity : Real;
    }

    item def ElectricalSignal {
        attribute voltage : Real;
        attribute current : Real;
    }

    value type FlowRate {
        unit = "m^3/s";
        quantityKind = "volume flow rate";
    }

    value type Volume {
        unit = "m^3";
        quantityKind = "volume";
    }

    value type Length {
        unit = "m";
        quantityKind = "length";
    }

    value type AngularSpeed {
        unit = "rad/s";
        quantityKind = "angular speed";
    }

    value type Torque {
        unit = "N*m";
        quantityKind = "torque";
    }

    value type Efficiency {
        unit = "1";
        quantityKind = "ratio";
    }

    value type Power {
        unit = "W";
        quantityKind = "power";
    }

    value type Time {
        unit = "s";
        quantityKind = "time";
    }

    value type Mass {
        unit = "kg";
        quantityKind = "mass";
    }

    port def WaterIntakePort {
        in item incomingWater : Water;
        attribute intakeFlowCapacity : FlowRate;
    }

    port def WaterDischargePort {
        out item liftedWater : Water;
        attribute dischargeFlowCapacity : FlowRate;
    }

    port def ShaftPowerPort {
        inout item shaftPower : MechanicalPower;
        attribute ratedTorque : Torque;
        attribute ratedSpeed : AngularSpeed;
    }

    port def ControlSignalPort {
        in item command : ElectricalSignal;
        out item status : ElectricalSignal;
    }

    part def RiverSource {
        attribute availableFlow : FlowRate = 0.35;
        attribute waterLevel : Length = 1.20;
        port outlet : WaterIntakePort;
    }

    part def IntakeChannel {
        attribute channelWidth : Length = 0.80;
        attribute channelDepth : Length = 0.45;
        attribute inletLossCoefficient : Real = 0.18;
        port riverInlet : WaterIntakePort;
        port wheelFeed : WaterIntakePort;
    }

    part def NoriaWheel {
        attribute wheelDiameter : Length = 6.00;
        attribute wheelWidth : Length = 0.75;
        attribute nominalAngularSpeed : AngularSpeed = 0.42;
        attribute maximumAngularSpeed : AngularSpeed = 0.65;
        attribute rotationalEfficiency : Efficiency = 0.72;
        attribute ratedTorque : Torque = 1850.0;

        port hydraulicDrive : WaterIntakePort;
        port shaft : ShaftPowerPort;

        part axle {
            attribute diameter : Length = 0.18;
            attribute bearingFrictionTorque : Torque = 75.0;
        }

        part rim {
            attribute radius : Length = 3.00;
            attribute structuralMass : Mass = 1250.0;
        }

        part spokes {
            attribute count : Integer = 32;
            attribute spokeLength : Length = 2.85;
        }
    }

    part def BucketAssembly {
        attribute bucketCount : Integer = 48;
        attribute bucketVolume : Volume = 0.035;
        attribute fillFractionAtNominalSpeed : Efficiency = 0.78;
        attribute leakageRatePerBucket : FlowRate = 0.00008;
        attribute liftedHead : Length = 5.25;

        port scoopInlet : WaterIntakePort;
        port dischargeOutlet : WaterDischargePort;

        action scoopWater {
            in item sourceWater : Water;
            out item capturedWater : Water;
        }

        action liftWater {
            in item capturedWater : Water;
            out item elevatedWater : Water;
        }

        action emptyBucket {
            in item elevatedWater : Water;
            out item deliveredWater : Water;
        }
    }

    part def Trough {
        attribute troughLength : Length = 8.00;
        attribute troughSlope : Real = 0.015;
        attribute storageVolume : Volume = 0.18;
        port inlet : WaterDischargePort;
        port outlet : WaterDischargePort;
    }

    part def DeliveryCanal {
        attribute canalLength : Length = 42.0;
        attribute deliveryCapacity : FlowRate = 0.080;
        attribute destinationElevation : Length = 5.05;
        port inlet : WaterDischargePort;
        port outlet : WaterDischargePort;
    }

    part def BrakeAndGovernor {
        attribute overspeedThreshold : AngularSpeed = 0.60;
        attribute brakeTorqueCapacity : Torque = 2200.0;
        attribute restartDelay : Time = 30.0;

        port shaftInterface : ShaftPowerPort;
        port controllerInterface : ControlSignalPort;

        state def GovernorState {
            state idle;
            state regulating;
            state braking;
            state lockedOut;

            transition first idle;
            transition idle_to_regulating
                first idle then regulating;

            transition regulating_to_braking
                first regulating then braking
                if currentWheelSpeed > overspeedThreshold;

            transition braking_to_regulating
                first braking then regulating
                if currentWheelSpeed <= nominalWheelSpeed;

            transition braking_to_lockedOut
                first braking then lockedOut
                if brakeDuration > restartDelay;
        }

        attribute currentWheelSpeed : AngularSpeed;
        attribute nominalWheelSpeed : AngularSpeed = 0.42;
        attribute brakeDuration : Time;
    }

    part def SupportStructure {
        attribute foundationMass : Mass = 5600.0;
        attribute frameHeight : Length = 6.40;
        attribute allowableStaticLoad : Mass = 9200.0;

        part masonryPiers {
            attribute pierCount : Integer = 2;
            attribute pierHeight : Length = 3.20;
        }

        part timberFrame {
            attribute beamCount : Integer = 14;
            attribute maximumDeflection : Length = 0.012;
        }
    }

    part def OperatorPanel {
        port governorCommand : ControlSignalPort;
        attribute emergencyStopAvailable : Boolean = true;
        attribute flowDisplayRange : FlowRate = 0.100;
    }

    part def NoriaSystem {
        attribute designLiftHeight : Length = 5.25;
        attribute nominalDeliveredFlow : FlowRate = 0.052;
        attribute minimumDeliveredFlow : FlowRate = 0.035;
        attribute maximumSafeWheelSpeed : AngularSpeed = 0.65;
        attribute intendedFunction : String = "Lift water from a lower flowing source to an elevated trough for gravity-fed distribution.";

        part river : RiverSource;
        part intake : IntakeChannel;
        part wheel : NoriaWheel;
        part buckets : BucketAssembly;
        part trough : Trough;
        part canal : DeliveryCanal;
        part governor : BrakeAndGovernor;
        part support : SupportStructure;
        part panel : OperatorPanel;

        port waterSourceInterface : WaterIntakePort;
        port elevatedWaterInterface : WaterDischargePort;
        port operatorInterface : ControlSignalPort;

        connect waterSourceInterface to river.outlet;
        connect river.outlet to intake.riverInlet;
        connect intake.wheelFeed to wheel.hydraulicDrive;
        connect intake.wheelFeed to buckets.scoopInlet;
        connect wheel.shaft to governor.shaftInterface;
        connect buckets.dischargeOutlet to trough.inlet;
        connect trough.outlet to canal.inlet;
        connect canal.outlet to elevatedWaterInterface;
        connect panel.governorCommand to governor.controllerInterface;
        connect operatorInterface to panel.governorCommand;

        action performPrimaryFunction {
            in item lowElevationWater : Water;
            out item elevatedWater : Water;

            first start;
            then scoop : buckets.scoopWater;
            then lift : buckets.liftWater;
            then discharge : buckets.emptyBucket;
            then deliver;
        }

        state def OperatingState {
            state stopped;
            state starting;
            state liftingWater;
            state regulatingFlow;
            state emergencyStopped;
            state maintenance;

            transition initial_to_stopped
                first stopped;

            transition stopped_to_starting
                first stopped then starting
                if operatorStartCommand == true and maintenanceMode == false;

            transition starting_to_lifting
                first starting then liftingWater
                if currentWheelSpeed >= minimumLiftSpeed;

            transition lifting_to_regulating
                first liftingWater then regulatingFlow
                if deliveredFlow >= minimumDeliveredFlow;

            transition regulating_to_lifting
                first regulatingFlow then liftingWater
                if deliveredFlow < minimumDeliveredFlow;

            transition any_to_emergencyStopped
                first liftingWater then emergencyStopped
                if emergencyStopCommand == true;

            transition emergencyStopped_to_stopped
                first emergencyStopped then stopped
                if resetCommand == true;

            transition stopped_to_maintenance
                first stopped then maintenance
                if maintenanceMode == true;

            transition maintenance_to_stopped
                first maintenance then stopped
                if maintenanceMode == false;
        }

        attribute operatorStartCommand : Boolean;
        attribute emergencyStopCommand : Boolean;
        attribute resetCommand : Boolean;
        attribute maintenanceMode : Boolean;
        attribute currentWheelSpeed : AngularSpeed;
        attribute minimumLiftSpeed : AngularSpeed = 0.25;
        attribute deliveredFlow : FlowRate;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Noria system shall convert energy from flowing water into rotary motion and use bucket assemblies attached to the wheel to raise water from a lower source to an elevated discharge trough for gravity-fed distribution. */
        subject system : NoriaSystem;
        require constraint {
            system.nominalDeliveredFlow >= system.minimumDeliveredFlow
        }
    }

    requirement def LiftHeightRequirement {
        doc /* The Noria system shall lift water at least 5.0 meters above the source water level under nominal operating conditions. */
        subject system : NoriaSystem;
        require constraint {
            system.designLiftHeight >= 5.0
        }
    }

    requirement def FlowDeliveryRequirement {
        doc /* The Noria system shall deliver at least 0.035 cubic meters per second of water to the elevated outlet during normal operation. */
        subject system : NoriaSystem;
        require constraint {
            system.nominalDeliveredFlow >= 0.035
        }
    }

    requirement def OverspeedProtectionRequirement {
        doc /* The Noria system shall limit wheel speed to the maximum safe wheel speed by braking or regulating the shaft when overspeed is detected. */
        subject system : NoriaSystem;
        require constraint {
            system.currentWheelSpeed <= system.maximumSafeWheelSpeed
        }
    }

    requirement def PassiveWaterLiftingRequirement {
        doc /* The primary water lifting function shall not require external electrical power during normal operation; flowing water shall provide the driving energy. */
        subject system : NoriaSystem;
        require constraint {
            system.wheel.rotationalEfficiency > 0.60
        }
    }

    requirement def MaintainabilityRequirement {
        doc /* The system shall support a maintenance state in which rotation is stopped, bucket inspection is possible, and restart requires exit from maintenance mode. */
        subject system : NoriaSystem;
        require constraint {
            system.maintenanceMode == false implies system.operatorStartCommand == true
        }
    }

    satisfy PrimaryFunctionRequirement by NoriaSystem::performPrimaryFunction;
    satisfy LiftHeightRequirement by NoriaSystem::buckets;
    satisfy FlowDeliveryRequirement by NoriaSystem::canal;
    satisfy OverspeedProtectionRequirement by NoriaSystem::governor;
    satisfy PassiveWaterLiftingRequirement by NoriaSystem::wheel;
    satisfy MaintainabilityRequirement by NoriaSystem::OperatingState;
}