package DeepSpaceProbe {
    private import ISQ::*;
    private import ScalarValues::*;

    item def Power;
    item def Command;
    item def Telemetry;
    item def ScienceData;
    item def PositionVector;
    item def VelocityVector;
    item def AttitudeVector;
    value def TemperatureValue :> Real;

    item def TargetAcquired;
    item def DataCollected;
    item def TransmissionComplete;
    item def LowPowerAlert;
    item def SystemMalfunction;

    part def PowerSubsystem {
        port powerOutPort { out power : Power; }
        port powerStatusPort { out status : String; }
        part solarPanels;
        part batteries {
            attribute charge : Real;
        }
        perform action generatePower;
        perform action distributePower;
    }

    part def CommunicationSubsystem {
        port cmdInPort { in cmd : Command; }
        port dataInPort { in data : ScienceData; }
        port telemetryOutPort { out telemetry : Telemetry; }
        port powerInPort { in power : Power; }
        part highGainAntenna;
        perform action receiveCommands;
        perform action transmitData;
    }

    part def AttitudeControlSubsystem {
        port powerInPort { in power : Power; }
        port attitudeCmdPort { in targetAttitude : AttitudeVector; }
        port currentAttitudePort { out currentAttitude : AttitudeVector; }
        part reactionWheels[4];
        part thrusters;
        perform action orientSpacecraft;
    }

    part def ScienceInstrumentSubsystem {
        port powerInPort { in power : Power; }
        port pointingPort { in attitude : AttitudeVector; }
        port dataOutPort { out data : ScienceData; }
        part multispectralImagingSpectrometer;
        perform action collectData;
    }

    part def DataStorageSubsystem {
        port powerInPort { in power : Power; }
        port dataInPort { in data : ScienceData; }
        port dataOutPort { out data : ScienceData; }
        part memoryBuffer;
        perform action storeData;
        perform action retrieveData;
    }

    part def NavigationSubsystem {
        port powerInPort { in power : Power; }
        port positionPort { out position : PositionVector; }
        port velocityPort { out velocity : VelocityVector; }
        part starTracker;
        part onboardSensors;
        perform action determineState;
        perform action planManeuver;
        perform action executeManeuver;
    }

    part def ThermalControlSubsystem {
        port powerInPort { in power : Power; }
        port tempStatusPort { out temp : TemperatureValue; }
        part radiators;
        part heaters;
        perform action regulateTemperature;
    }

    part def DeepSpaceProbeSystem {
        part powerSubsystem : PowerSubsystem;
        part commSubsystem : CommunicationSubsystem;
        part attitudeControlSubsystem : AttitudeControlSubsystem;
        part scienceSubsystem : ScienceInstrumentSubsystem;
        part dataStorageSubsystem : DataStorageSubsystem;
        part navSubsystem : NavigationSubsystem;
        part thermalControlSubsystem : ThermalControlSubsystem;

        connect powerSubsystem.powerOutPort to commSubsystem.powerInPort;
        connect powerSubsystem.powerOutPort to attitudeControlSubsystem.powerInPort;
        connect powerSubsystem.powerOutPort to scienceSubsystem.powerInPort;
        connect powerSubsystem.powerOutPort to dataStorageSubsystem.powerInPort;
        connect powerSubsystem.powerOutPort to navSubsystem.powerInPort;
        connect powerSubsystem.powerOutPort to thermalControlSubsystem.powerInPort;

        connect scienceSubsystem.dataOutPort to dataStorageSubsystem.dataInPort;
        connect dataStorageSubsystem.dataOutPort to commSubsystem.dataInPort;
        
        connect attitudeControlSubsystem.currentAttitudePort to scienceSubsystem.pointingPort;

        exhibit state 'Probe Operational States' {
            entry; then normal;
            state normal {
                entry; then pointing;
                state pointing;
                accept TargetAcquired
                    do attitudeControlSubsystem.orientSpacecraft
                    then collecting;
                state collecting {
                    do scienceSubsystem.collectData;
                }
                accept DataCollected
                    do dataStorageSubsystem.storeData
                    then transmitting;
                state transmitting {
                    do commSubsystem.transmitData;
                }
                accept TransmissionComplete
                    then pointing;
            }
            
            accept LowPowerAlert 
                then safeMode;
            accept SystemMalfunction 
                then safeMode;
                
            state safeMode {
                entry; then stabilize;
                state stabilize {
                    do attitudeControlSubsystem.orientSpacecraft;
                }
                accept Command
                    then normal;
            }
        }
    }

    requirement def PowerManagementRequirement {
        subject p : PowerSubsystem;
        doc /* The power subsystem shall maintain sufficient charge for operations. */
        constraint { p.batteries.charge > 0.0; }
    }
    
    requirement def AutonomousOperationRequirement {
        subject s : DeepSpaceProbeSystem;
        doc /* The probe shall autonomously manage all critical functions without real-time Earth control. */
    }
}
