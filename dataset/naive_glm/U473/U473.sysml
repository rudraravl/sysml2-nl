package IndustrialPumpingSubsystem {
    import SI::*;
    import ISQ::*;
    import ScalarValues::*;

    item def Liquid;

    port def FluidPort {
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
        flow liquid : Liquid;
    }

    requirement def PumpPerformanceRequirement {
        subject p : BigPump;
        require {
            p.ratedFlowRate >= 0.05 [m3/s];
            p.motorPower >= 15000 [W];
        }
    }

    requirement def PumpSafetyRequirement {
        subject p : BigPump;
        require {
            p.currentDischargePressure <= p.maxSafeDischargePressure;
        }
    }

    part def BigPump {
        attribute ratedFlowRate : VolumeFlowRate = 0.05 [m3/s];
        attribute maxSafeDischargePressure : Pressure = 800000 [Pa];
        attribute motorPower : Power = 15000 [W];

        port suctionPort : FluidPort;
        port dischargePort : FluidPort;

        attribute currentDischargePressure : Pressure = 0 [Pa];
        attribute currentFlowRate : VolumeFlowRate = 0 [m3/s];
        attribute isRunning : Boolean = false;
        attribute faultDetected : Boolean = false;

        action def PressurizeFluid {
            in fluid : Liquid;
            out pressurizedFluid : Liquid;
        }

        exhibit state PumpLifecycle {
            state stopped;
            state starting;
            state operating {
                entry {
                    assign currentFlowRate = ratedFlowRate;
                    assign currentDischargePressure = 500000 [Pa];
                }
                exit {
                    assign currentFlowRate = 0 [m3/s];
                    assign currentDischargePressure = 0 [Pa];
                }
            }
            state faulted;

            transition stopped -> starting when isRunning;
            transition starting -> operating after 3 [s];
            transition operating -> stopped when !isRunning;
            transition operating -> faulted when currentDischargePressure > maxSafeDischargePressure;
            transition faulted -> stopped when !isRunning;
        }
    }

    part def FluidTank {
        port fluidPort : FluidPort;
        attribute capacity : Volume = 10 [m3];
        attribute currentVolume : Volume;
    }

    part def PumpingSubsystem {
        part sourceTank : FluidTank {
            attribute currentVolume = 8 [m3];
        }

        part destinationTank : FluidTank {
            attribute currentVolume = 0 [m3];
        }

        part bigPump : BigPump;

        connection sourceTank.fluidPort <-> bigPump.suctionPort;
        connection bigPump.dischargePort <-> destinationTank.fluidPort;

        requirement pumpPerformanceRequirement : PumpPerformanceRequirement {
            subject p = bigPump;
        }

        requirement pumpSafetyRequirement : PumpSafetyRequirement {
            subject p = bigPump;
        }

        satisfy pumpPerformanceRequirement by bigPump;
        satisfy pumpSafetyRequirement by bigPump;
    }
}
