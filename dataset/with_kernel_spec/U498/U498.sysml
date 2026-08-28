package FlexibleImpellerPumpSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def EmergencyStopCommand;
        attribute def SpeedReached;
        attribute def MotorStopped;
        attribute def TempAlert;
        attribute def TempNormal;

        item def Fluid {
            attribute viscosity : Real;
            attribute density : Real;
            attribute hasEntrainedAir : Boolean;
        }

        port def FluidPort {
            inout fluid : Fluid;
            attribute flowRate :> ISQ::volumeFlowRate;
            attribute pressure :> ISQ::pressure;
        }

        port def DrivePwrPort {
            attribute torque :> ISQ::torque;
            attribute speed :> ISQ::angularVelocity;
        }

        port def CmdPort {
            in attribute startCmd : StartCommand;
            in attribute stopCmd : StopCommand;
            in attribute emergencyStopCmd : EmergencyStopCommand;
        }

        action def ProvidePumping {
            in fluidIn : Fluid;
            out fluidOut : Fluid;
            attribute flowRate :> ISQ::volumeFlowRate;
            attribute dischargePressure :> ISQ::pressure;
        }

        action def AccelerateMotor {
            attribute targetSpeed :> ISQ::angularVelocity;
        }

        action def DecelerateMotor;
        action def SelfPrime;
        action def PerformSelfTest;

        part def FlexibleImpeller {
            attribute numBlades : Integer = 8;
            attribute material : String = "rubber";
            attribute maxOperatingTemp :> ISQ::temperature = 353.15 [K];
            attribute maxDryRunTime :> ISQ::time = 30 [s];
            attribute wearResistance : Real;
        }

        part def PumpCasing {
            attribute material : String = "bronze";
            attribute eccentricOffset :> ISQ::length;
        }

        part def DriveShaft {
            attribute material : String = "stainless steel";
            attribute diameter :> ISQ::length;
            port inPort : ~DrivePwrPort;
            port outPort : DrivePwrPort;
        }

        part def ElectricMotor {
            attribute ratedSpeed :> ISQ::angularVelocity;
            attribute ratedTorque :> ISQ::torque;
            port drivePwrPort : DrivePwrPort;
        }

        part def CheckValve {
            attribute crackingPressure :> ISQ::pressure;
            port inletPort : FluidPort;
            port outletPort : FluidPort;
        }

        part def PumpUnit {
            part impeller : FlexibleImpeller;
            part casing : PumpCasing;
            port drivePwrPort : ~DrivePwrPort;
            port suctionPort : FluidPort;
            port dischargePort : FluidPort;
            perform action providePumping : ProvidePumping;
            perform action selfPrime : SelfPrime;
        }

        part def FlexibleImpellerPump {
            attribute maxFlowRate :> ISQ::volumeFlowRate;
            attribute maxDischargePressure :> ISQ::pressure;
            attribute currentTemp :> ISQ::temperature;
            port suctionPort : FluidPort;
            port dischargePort : FluidPort;
            port cmdPort : CmdPort;

            part pumpUnit : PumpUnit;
            part motor : ElectricMotor;
            part driveShaft : DriveShaft;
            part suctionCheckValve : CheckValve;
            part dischargeCheckValve : CheckValve;

            perform action providePumping : ProvidePumping;
            perform action accelerateMotor : AccelerateMotor;
            perform action decelerateMotor : DecelerateMotor;
            perform action performSelfTest : PerformSelfTest;

            exhibit state pumpStates parallel {
                state operationalStates {
                    entry action initial;
                    state off;
                    state starting {
                        entry action performSelfTest;
                        do accelerateMotor;
                    }
                    state running {
                        do providePumping;
                    }
                    state stopping {
                        do decelerateMotor;
                    }
                    transition initial then off;
                    transition off_to_starting
                        first off
                        accept startCmd : StartCommand via cmdPort
                        then starting;
                    transition starting_to_running
                        first starting
                        accept SpeedReached
                        then running;
                    transition running_to_stopping
                        first running
                        accept stopCmd : StopCommand via cmdPort
                        then stopping;
                    transition stopping_to_off
                        first stopping
                        accept MotorStopped
                        then off;
                    transition starting_emergency
                        first starting
                        accept emergencyStopCmd : EmergencyStopCommand via cmdPort
                        then off;
                    transition running_emergency
                        first running
                        accept emergencyStopCmd : EmergencyStopCommand via cmdPort
                        then off;
                    transition stopping_emergency
                        first stopping
                        accept emergencyStopCmd : EmergencyStopCommand via cmdPort
                        then off;
                }
                state healthStates {
                    entry action initial;
                    state normal;
                    state degraded;
                    transition initial then normal;
                    transition normal_to_degraded
                        first normal
                        accept TempAlert
                        then degraded;
                    transition degraded_to_normal
                        first degraded
                        accept TempNormal
                        then normal;
                }
            }

            connect motor.drivePwrPort to driveShaft.inPort;
            connect driveShaft.outPort to pumpUnit.drivePwrPort;
            connect suctionPort to suctionCheckValve.inletPort;
            connect suctionCheckValve.outletPort to pumpUnit.suctionPort;
            connect pumpUnit.dischargePort to dischargeCheckValve.inletPort;
            connect dischargeCheckValve.outletPort to dischargePort;
        }

        requirement def FlowRateRequirement {
            subject pump : FlexibleImpellerPump;
            doc /* The pump must achieve a minimum flow rate of 50 L/min under nominal operating conditions. */
            require constraint {
                pump.maxFlowRate >= 0.000833 [m^3/s]
            }
        }

        requirement def DischargePressureRequirement {
            subject pump : FlexibleImpellerPump;
            doc /* The pump must achieve a minimum discharge pressure of 200 kPa. */
            require constraint {
                pump.maxDischargePressure >= 200000 [Pa]
            }
        }

        requirement def ImpellerDurabilityRequirement {
            subject impeller : FlexibleImpeller;
            doc /* The impeller must withstand wear, elevated temperatures up to 80 degrees C, and brief dry running up to 30 seconds. */
            require constraint {
                impeller.maxOperatingTemp >= 353.15 [K] and
                impeller.maxDryRunTime >= 30 [s]
            }
        }

        requirement def SelfPrimingRequirement {
            subject pump : FlexibleImpellerPump;
            doc /* The pump must be self-priming, capable of drawing fluid without external priming. */
            require constraint {
                pump.maxFlowRate > 0.0 [m^3/s]
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part flexPump : FlexibleImpellerPump {
            requirement flowRateReq : FlowRateRequirement;
            requirement dischargePressureReq : DischargePressureRequirement;
            requirement impellerDurabilityReq : ImpellerDurabilityRequirement;
            requirement selfPrimingReq : SelfPrimingRequirement;

            satisfy flowRateReq by self;
            satisfy dischargePressureReq by self;
            satisfy impellerDurabilityReq by pumpUnit.impeller;
            satisfy selfPrimingReq by self;
        }
    }
}
