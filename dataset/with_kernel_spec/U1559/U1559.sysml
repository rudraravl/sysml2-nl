package MarsRoverSystem {

    package Definitions {
        item def Command;
        item def Telemetry;
        item def ScienceData;
        item def ImageData :> ScienceData {
            attribute width : ScalarValues::Integer;
            attribute height : ScalarValues::Integer;
            attribute pixelData : ScalarValues::String;
        }
        item def RockCompositionData :> ScienceData {
            attribute elements : ScalarValues::String[*];
            attribute percentages : ScalarValues::Real[*];
        }
        item def PositionData {
            attribute x : ISQ::length;
            attribute y : ISQ::length;
            attribute z : ISQ::length;
        }

        attribute def SigActivate;
        attribute def SigDeactivate;
        attribute def SigStartMission;
        attribute def SigDriveCommand;
        attribute def SigScienceCommand;
        attribute def SigCommunicateCommand;
        attribute def SigLowPower;
        attribute def SigPowerRestored;
        attribute def SigArrived;
        attribute def SigAnalysisDone;
        attribute def SigTransmitted;
        attribute def SigMissionComplete;
        attribute def SigShutdown;

        part def Wheel {
            attribute diameter : ISQ::length;
            port powerIn {
                in attribute power : ISQ::power;
            }
            perform action rotate {
                in speed : ISQ::speed;
            }
        }

        part def NavigationCamera {
            port imageOut {
                out item image : ImageData;
            }
            perform action captureImage {
                out image : ImageData;
            }
        }

        part def InertialMeasurementUnit {
            port sensorOut {
                out attribute acceleration : ISQ::acceleration;
                out attribute angularVelocity : ISQ::angularVelocity;
            }
            perform action readSensors {
                out acceleration : ISQ::acceleration;
                out angularVelocity : ISQ::angularVelocity;
            }
        }

        part def NavigationSystem {
            part cameras[2] : NavigationCamera;
            part imu : InertialMeasurementUnit;
            port navOut {
                out item position : PositionData;
                out attribute orientation : ISQ::planeAngle;
            }
            perform action determinePosition {
                out position : PositionData;
                out orientation : ISQ::planeAngle;
            }
        }

        part def MobilitySubsystem {
            part wheels[6] : Wheel;
            part navigationSystem : NavigationSystem;
            port powerIn {
                in attribute power : ISQ::power;
            }
            port navDataOut {
                out item position : PositionData;
                out attribute orientation : ISQ::planeAngle;
            }
            port commandIn {
                in item command : Command;
            }
            perform action driveToLocation {
                in targetPosition : PositionData;
                first start;
                then action computePath;
                then action moveWheels;
                then done;
            }
        }

        part def SolarPanelArray {
            attribute area : ISQ::area;
            attribute efficiency : ScalarValues::Real;
            port powerOut {
                out attribute power : ISQ::power;
            }
            perform action generatePower {
                out power : ISQ::power;
            }
        }

        part def BatteryModule {
            attribute capacity : ISQ::energy;
            attribute currentCharge : ISQ::energy;
            port chargeIn {
                in attribute power : ISQ::power;
            }
            port dischargeOut {
                out attribute power : ISQ::power;
            }
            perform action charge {
                in power : ISQ::power;
            }
            perform action discharge {
                out power : ISQ::power;
            }
        }

        part def PowerManagementUnit {
            port solarIn {
                in attribute power : ISQ::power;
            }
            port batteryIn {
                in attribute power : ISQ::power;
            }
            port powerOut {
                out attribute power : ISQ::power;
            }
            port statusOut {
                out attribute batteryStateOfCharge : ScalarValues::Real;
                out attribute lowPowerWarning : ScalarValues::Boolean;
            }
            perform action managePower {
                first start;
                then action distributePower;
                then action monitorBattery;
                then done;
            }
        }

        part def PowerSubsystem {
            part solarArrays[2] : SolarPanelArray;
            part battery : BatteryModule;
            part pmu : PowerManagementUnit;
            port powerOut {
                out attribute power : ISQ::power;
            }
            port statusOut {
                out attribute batteryStateOfCharge : ScalarValues::Real;
                out attribute lowPowerWarning : ScalarValues::Boolean;
            }
            connect solarArrays.powerOut to pmu.solarIn;
            connect battery.dischargeOut to pmu.batteryIn;
            connect pmu.powerOut to powerOut;
            connect pmu.statusOut to statusOut;
        }

        part def PanoramicCamera {
            attribute resolution : ScalarValues::Integer;
            port imageOut {
                out item image : ImageData;
            }
            perform action capturePanorama {
                out image : ImageData;
            }
        }

        part def RockAbrasionTool {
            port powerIn {
                in attribute power : ISQ::power;
            }
            port commandIn {
                in item command : Command;
            }
            perform action grindRock {
                out preparedSurface : ScalarValues::Boolean;
            }
        }

        part def AlphaParticleXRaySpectrometer {
            port dataOut {
                out item composition : RockCompositionData;
            }
            port commandIn {
                in item command : Command;
            }
            perform action analyzeComposition {
                out composition : RockCompositionData;
            }
        }

        part def SciencePayload {
            part mast {
                part panoramicCameras[2] : PanoramicCamera;
            }
            part rockAbrasionTool : RockAbrasionTool;
            part apxs : AlphaParticleXRaySpectrometer;
            port powerIn {
                in attribute power : ISQ::power;
            }
            port dataOut {
                out item data : ScienceData;
            }
            port commandIn {
                in item command : Command;
            }
            perform action performScienceSequence {
                first start;
                then action captureImages;
                then action prepareRockSurface;
                then action analyzeRock;
                then done;
            }
        }

        part def HighGainAntenna {
            attribute azimuth : ISQ::planeAngle;
            attribute elevation : ISQ::planeAngle;
            port rfIn {
                in item command : Command;
            }
            port rfOut {
                out item telemetry : Telemetry;
            }
            perform action steer {
                in azimuth : ISQ::planeAngle;
                in elevation : ISQ::planeAngle;
            }
        }

        part def Transmitter {
            attribute transmitPower : ISQ::power;
            port telemetryIn {
                in item telemetry : Telemetry;
            }
            port powerIn {
                in attribute power : ISQ::power;
            }
            port signalOut {
                out item telemetry : Telemetry;
            }
            perform action transmitData {
                in data : Telemetry;
            }
        }

        part def Receiver {
            attribute sensitivity : ScalarValues::Real;
            port signalIn {
                in item command : Command;
            }
            port commandOut {
                out item command : Command;
            }
            perform action receiveCommand {
                out command : Command;
            }
        }

        part def CommunicationsSubsystem {
            part highGainAntenna : HighGainAntenna;
            part transmitter : Transmitter;
            part receiver : Receiver;
            port cmdOut {
                out item command : Command;
            }
            port dataIn {
                in item telemetry : Telemetry;
            }
            port powerIn {
                in attribute power : ISQ::power;
            }
            connect highGainAntenna.rfIn to receiver.signalIn;
            connect receiver.commandOut to cmdOut;
            connect dataIn to transmitter.telemetryIn;
            connect transmitter.signalOut to highGainAntenna.rfOut;
            perform action receiveCommand {
                out command : Command;
            }
            perform action transmitData {
                in data : Telemetry;
            }
        }

        part def OnboardComputer {
            port commandIn {
                in item command : Command;
            }
            port commandOut {
                out item command : Command;
            }
            port dataIn {
                in item data : ScienceData;
            }
            port dataOut {
                out item telemetry : Telemetry;
            }
            port powerIn {
                in attribute power : ISQ::power;
            }
            port statusIn {
                in attribute batteryStateOfCharge : ScalarValues::Real;
                in attribute lowPowerWarning : ScalarValues::Boolean;
            }
            perform action processCommand {
                in command : Command;
            }
            perform action collectData {
                out data : Telemetry;
            }
            perform action scheduleTasks;
        }

        part def ThermalControlSystem {
            attribute minTemp : ISQ::temperature;
            attribute maxTemp : ISQ::temperature;
            part heaters;
            part radiators;
            part temperatureSensors {
                perform action readTemperature {
                    out temp : ISQ::temperature;
                }
            }
            port powerIn {
                in attribute power : ISQ::power;
            }
            perform action regulateTemperature {
                in currentTemp : ISQ::temperature;
                out heaterPower : ISQ::power;
                first start;
                then action measureTemp;
                then action adjustHeaters;
                then action adjustRadiators;
                then done;
            }
        }

        part def MarsRover {
            attribute mass : ISQ::mass;
            attribute position : PositionData;
            attribute orientation : ISQ::planeAngle;

            part mobility : MobilitySubsystem;
            part power : PowerSubsystem;
            part science : SciencePayload;
            part comms : CommunicationsSubsystem;
            part computer : OnboardComputer;
            part thermal : ThermalControlSystem;

            connect power.powerOut to computer.powerIn;
            connect power.powerOut to mobility.powerIn;
            connect power.powerOut to science.powerIn;
            connect power.powerOut to comms.powerIn;
            connect power.powerOut to thermal.powerIn;

            connect comms.cmdOut to computer.commandIn;
            connect computer.commandOut to mobility.commandIn;
            connect computer.commandOut to science.commandIn;
            connect mobility.navDataOut to computer.dataIn;
            connect science.dataOut to computer.dataIn;
            connect computer.dataOut to comms.dataIn;
            connect power.statusOut to computer.statusIn;

            exhibit state roverStates {
                entry; then off;
                state off;
                accept SigActivate then standby;
                state standby;
                accept SigStartMission then active;
                state active {
                    entry; then idle;
                    state idle;
                    accept SigDriveCommand then driving;
                    state driving {
                        do mobility.driveToLocation;
                    }
                    accept SigArrived then analyzing;
                    state analyzing {
                        do science.performScienceSequence;
                    }
                    accept SigAnalysisDone then transmitting;
                    state transmitting {
                        do comms.transmitData;
                    }
                    accept SigTransmitted then idle;
                    accept SigLowPower then lowPower;
                    state lowPower {
                        do power.pmu.managePower;
                    }
                    accept SigPowerRestored then idle;
                }
                accept SigMissionComplete then standby;
                accept SigShutdown then off;
            }

            perform action operationalCycle {
                first start;
                then action checkPowerStatus;
                then action receiveCommands;
                then action driveToTarget;
                then action performScience;
                then action transmitData;
                then done;
            }
        }
    }

    requirement def MassRequirement {
        doc /* The rover total mass shall not exceed 1000 kg. */
        subject rover : Definitions::MarsRover;
        assert constraint { rover.mass <= 1000 [ISQ::kilogram] }
    }

    requirement def TemperatureRequirement {
        doc /* The rover shall maintain internal components between -40C and 40C. */
        subject rover : Definitions::MarsRover;
        attribute minTemp : ISQ::temperature;
        attribute maxTemp : ISQ::temperature;
    }

    requirement def PowerRequirement {
        doc /* The rover shall operate for at least 90 sols on a single charge. */
        subject rover : Definitions::MarsRover;
        attribute minEnergy : ISQ::energy;
        assert constraint { rover.power.battery.capacity >= minEnergy }
    }

    requirement def DataRequirement {
        doc /* The rover shall transmit at least 100 Mbits of science data per sol. */
        subject rover : Definitions::MarsRover;
        attribute minDataPerSol : ScalarValues::Real;
    }

    requirement def MobilityRequirement {
        doc /* The rover shall traverse rocky terrain using six motorized wheels. */
        subject rover : Definitions::MarsRover;
    }

    part marsRover : Definitions::MarsRover {
        :>> mass = 900 [ISQ::kilogram];
    }
}
