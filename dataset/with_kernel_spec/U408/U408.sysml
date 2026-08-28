package 'Suzuki GSX-S 2024 Motorcycle Model' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        public import PartDefinitions::*;
        public import PortDefinitions::*;
        public import SignalDefinitions::*;
        public import RequirementDefinitions::*;

        package PartDefinitions {
            part def Frame {
                attribute mass :> ISQ::mass = 14.2 [kg];
                attribute maxLoadCapacity :> ISQ::mass = 195.0 [kg];
                attribute torsionalStiffness : ScalarValues::Real;
                attribute material : String = "High-Tensile Steel Alloy";

                port engineMountPort : MountPort;
                port frontSusMountPort : MountPort;
                port rearSusMountPort : MountPort;
                port riderStationMountPort : MountPort;
            }

            part def Engine {
                attribute displacement :> ISQ::volume = 749.0 [mL];
                attribute maxPower :> ISQ::power = 112.0 [kW];
                attribute maxTorque :> ISQ::torque = 78.0 [N*m];
                attribute mass :> ISQ::mass = 62.0 [kg];

                port frameMountPort : MountPort;
                port throttlePort : ThrottleCmdPort;
                port ignitionPort : IgnitionCmdPort;
                port torquePort : TorquePort;
                port vibrationPort : VibrationPort;

                perform action generatePower;
                perform action generateVibrations;
            }

            part def FrontSuspension {
                attribute type : String = "Telescopic Fork";
                attribute travel :> ISQ::length = 0.120 [m];
                attribute springRate : ScalarValues::Real;
                attribute dampingCoefficient : ScalarValues::Real;

                port frameMountPort : MountPort;
                port wheelMountPort : MountPort;
                port steeringPort : SteeringCmdPort;

                perform action absorbImpact;
                perform action allowSteering;
            }

            part def RearSuspension {
                attribute type : String = "Swingarm";
                attribute travel :> ISQ::length = 0.130 [m];
                attribute springRate : ScalarValues::Real;
                attribute dampingCoefficient : ScalarValues::Real;

                part shockAbsorber : ShockAbsorber;

                port frameMountPort : MountPort;
                port wheelMountPort : MountPort;

                perform action absorbImpact;
            }

            part def ShockAbsorber {
                attribute dampingCoefficient : ScalarValues::Real;
            }

            part def Wheel {
                attribute radius :> ISQ::length;
                attribute mass :> ISQ::mass;
                attribute type : String;

                port axlePort : MountPort;
                port drivePort : TorquePort;
                port brakePort : BrakeCmdPort;
                port roadPort : RoadPort;
            }

            part def FrontWheel :> Wheel {
                attribute redefines radius = 0.3175 [m];
                attribute redefines mass = 12.0 [kg];
                attribute redefines type = "Front";
            }

            part def RearWheel :> Wheel {
                attribute redefines radius = 0.3175 [m];
                attribute redefines mass = 14.0 [kg];
                attribute redefines type = "Rear";
            }

            part def RiderStation {
                attribute seatHeight :> ISQ::length = 0.82 [m];
                attribute handlebarWidth :> ISQ::length = 0.78 [m];

                port frameMountPort : MountPort;
                port throttleCmdPort : ThrottleCmdPort;
                port brakeCmdPort : BrakeCmdPort;
                port steeringCmdPort : SteeringCmdPort;
                port ignitionCmdPort : IgnitionCmdPort;
                port feedbackInPort : FeedbackPort;

                perform action provideCommands;
                perform action receiveFeedback;
            }

            part def Motorcycle {
                attribute dryMass :> ISQ::mass = 215.0 [kg];
                attribute riderMass :> ISQ::mass;
                attribute totalMass :> ISQ::mass = dryMass + riderMass;
                attribute maxLoad :> ISQ::mass = 195.0 [kg];
                attribute velocity :> ISQ::speed;
                attribute acceleration :> ISQ::acceleration;
                attribute throttlePosition : ScalarValues::Real;
                attribute brakeInput : ScalarValues::Real;
                attribute targetCruiseSpeed :> ISQ::speed;
                attribute diagnosticsPassed : Boolean;

                part mainFrame : Frame;
                part engine : Engine;
                part frontSuspension : FrontSuspension;
                part rearSuspension : RearSuspension;
                part frontWheel : FrontWheel;
                part rearWheel : RearWheel;
                part riderStation : RiderStation;

                port riderCmdPort : RiderCmdPort;
                port roadPort : RoadPort;

                connect engine.frameMountPort to mainFrame.engineMountPort;
                connect frontSuspension.frameMountPort to mainFrame.frontSusMountPort;
                connect rearSuspension.frameMountPort to mainFrame.rearSusMountPort;
                connect frontSuspension.wheelMountPort to frontWheel.axlePort;
                connect rearSuspension.wheelMountPort to rearWheel.axlePort;
                connect engine.torquePort to rearWheel.drivePort;
                connect riderStation.frameMountPort to mainFrame.riderStationMountPort;
                connect riderStation.throttleCmdPort to engine.throttlePort;
                connect riderStation.steeringCmdPort to frontSuspension.steeringPort;
                connect riderStation.brakeCmdPort to frontWheel.brakePort;
                connect riderStation.brakeCmdPort to rearWheel.brakePort;
                connect riderStation.ignitionCmdPort to engine.ignitionPort;
                connect frontWheel.roadPort to roadPort;
                connect rearWheel.roadPort to roadPort;
                connect frontWheel.roadPort to riderStation.feedbackInPort;
                connect rearWheel.roadPort to riderStation.feedbackInPort;

                perform action processRiderCommands;
                perform action providePower;
                perform action provideBraking;
                perform action controlDirection;
                perform action dampenVibrations;
                perform action performSystemCheck;
                perform action applyParkingBrake;
                perform action releaseParkingBrake;

                exhibit state motorcycleStates {
                    entry action initial;
                    state parked {
                        entry applyParkingBrake;
                    }
                    state starting {
                        entry performSystemCheck;
                    }
                    state moving {
                        entry action moving_initial;
                        do providePower;
                        do controlDirection;
                        do dampenVibrations;
                        state accelerating;
                        state cruising;
                        state decelerating;
                        transition moving_initial then accelerating;
                        transition accel_to_cruise
                            first accelerating
                            if throttlePosition == 0.0
                            then cruising;
                        transition cruise_to_accel
                            first cruising
                            if throttlePosition > 0.5
                            then accelerating;
                        transition cruise_to_decel
                            first cruising
                            if brakeInput > 0.1
                            then decelerating;
                        transition decel_to_accel
                            first decelerating
                            if throttlePosition > 0.5
                            then accelerating;
                        transition decel_to_cruise
                            first decelerating
                            if throttlePosition == 0.0 and brakeInput == 0.0
                            then cruising;
                    }
                    state stopping {
                        do provideBraking;
                    }

                    transition initial then parked;
                    transition parked_to_starting
                        first parked
                        accept IgnitionOnSignal
                        do releaseParkingBrake
                        then starting;
                    transition starting_to_moving
                        first starting
                        accept EngineReadySignal
                        if diagnosticsPassed
                        then moving;
                    transition moving_to_stopping
                        first moving
                        accept StopSignal
                        then stopping;
                    transition stopping_to_parked
                        first stopping
                        accept SpeedZeroSignal
                        do applyParkingBrake
                        then parked;
                }

                assert constraint maxLoadConstraint {
                    riderMass + dryMass <= maxLoad
                }
            }
        }

        package PortDefinitions {
            port def MountPort;
            port def TorquePort {
                attribute torque :> ISQ::torque;
            }
            port def RoadPort {
                attribute contactForce :> ISQ::force;
            }
            port def ThrottleCmdPort {
                attribute throttlePosition : ScalarValues::Real;
            }
            port def BrakeCmdPort {
                attribute brakeLevel : ScalarValues::Real;
            }
            port def SteeringCmdPort {
                attribute steeringAngle : ScalarValues::Real;
            }
            port def IgnitionCmdPort {
                attribute ignitionOn : Boolean;
            }
            port def RiderCmdPort {
                attribute throttle : ScalarValues::Real;
                attribute brake : ScalarValues::Real;
                attribute steering : ScalarValues::Real;
            }
            port def FeedbackPort {
                attribute feedbackForce :> ISQ::force;
            }
            port def VibrationPort {
                attribute vibrationLevel :> ISQ::force;
            }
        }

        package SignalDefinitions {
            item def IgnitionOnSignal;
            item def EngineReadySignal;
            item def StopSignal;
            item def SpeedZeroSignal;
        }

        package RequirementDefinitions {
            requirement def FrameMassRequirement {
                subject framePart : Frame;
                doc /* Frame mass must be kept low to optimize handling. */
                require constraint { framePart.mass <= 15.0 [kg] }
            }

            requirement def FrameLoadRequirement {
                subject framePart : Frame;
                doc /* Frame must support a maximum load of 195 kg. */
                require constraint { framePart.maxLoadCapacity >= 195.0 [kg] }
            }

            requirement def FrameMaterialRequirement {
                subject framePart : Frame;
                doc /* Frame must be constructed from high-tensile steel alloy. */
                require constraint { framePart.material == "High-Tensile Steel Alloy" }
            }

            requirement def EngineDisplacementRequirement {
                subject enginePart : Engine;
                doc /* Engine displacement must be 749 cc. */
                require constraint { enginePart.displacement == 749.0 [mL] }
            }

            requirement def EnginePowerRequirement {
                subject enginePart : Engine;
                doc /* Engine must produce at least 100 kW of power. */
                attribute minPower :> ISQ::power = 100.0 [kW];
                require constraint { enginePart.maxPower >= minPower }
            }

            requirement def MotorcycleLoadRequirement {
                subject motorcyclePart : Motorcycle;
                doc /* Motorcycle must support a maximum payload of 195 kg. */
                require constraint { motorcyclePart.maxLoad >= 195.0 [kg] }
            }

            requirement def MotorcycleStabilityRequirement {
                subject motorcyclePart : Motorcycle;
                doc /* Motorcycle must provide stable and responsive transportation for a single rider. */
                attribute minTorsionalStiffness : ScalarValues::Real = 10000.0;
                require constraint { motorcyclePart.mainFrame.torsionalStiffness >= minTorsionalStiffness }
            }
        }
    }

    part motorcycle : Motorcycle {
        attribute redefines riderMass = 85.0 [kg];
        part mainFrame : Frame {
            attribute redefines torsionalStiffness = 12500.0;
        }
        part frontSuspension : FrontSuspension {
            attribute redefines springRate = 10.5;
            attribute redefines dampingCoefficient = 1.2;
        }
        part rearSuspension : RearSuspension {
            attribute redefines springRate = 9.8;
            attribute redefines dampingCoefficient = 1.1;
        }
    }

    requirement frameMassReq : FrameMassRequirement;
    requirement frameLoadReq : FrameLoadRequirement;
    requirement frameMaterialReq : FrameMaterialRequirement;
    requirement engineDisplacementReq : EngineDisplacementRequirement;
    requirement enginePowerReq : EnginePowerRequirement;
    requirement motorcycleLoadReq : MotorcycleLoadRequirement;
    requirement motorcycleStabilityReq : MotorcycleStabilityRequirement;
}
