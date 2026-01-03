package 'Robotic Spacecraft System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MissionPhase;
    attribute def NavigationData;
    attribute def ScienceData;
    attribute def CommandData;
    attribute def TelemetryData;
    attribute def AttitudeData;
    attribute def PowerLevel;
    
    item def ElectricalPower {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    item def RadioSignal {
        attribute frequency : ISQ::FrequencyValue;
        attribute power : ISQ::PowerValue;
    }
    
    port def PowerPort {
        out item electricalPower : ElectricalPower;
    }
    
    port def DataPort {
        in item commandSignal : RadioSignal;
        out item telemetrySignal : RadioSignal;
    }
    
    port def SciencePort {
        out attribute scienceData : ScienceData;
    }
    
    part def PowerSubsystem {
        port powerOut : PowerPort;
        attribute solarArrayArea : ISQ::AreaValue;
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute currentPowerLevel : PowerLevel;
    }
    
    part def CommunicationSubsystem {
        port dataPort : DataPort;
        attribute antennaGain : Real;
        attribute transmitPower : ISQ::PowerValue;
    }
    
    part def AttitudeControlSubsystem {
        attribute currentAttitude : AttitudeData;
        attribute targetAttitude : AttitudeData;
        port powerIn : ~PowerPort;
    }
    
    part def PropulsionSubsystem {
        attribute fuelMass : ISQ::MassValue;
        attribute thrustCapacity : ISQ::ForceValue;
        port powerIn : ~PowerPort;
    }
    
    part def ScienceInstrumentSubsystem {
        port scienceOut : SciencePort;
        port powerIn : ~PowerPort;
        attribute dataRate : Real;
    }
    
    part def NavigationSubsystem {
        attribute position : NavigationData;
        attribute velocity : ISQ::SpeedValue;
        port powerIn : ~PowerPort;
    }
    
    part def CommandDataHandlingSubsystem {
        attribute storedCommands : CommandData[*];
        attribute storedTelemetry : TelemetryData[*];
        port powerIn : ~PowerPort;
    }
    
    action def GeneratePower {
        out powerOutput : ElectricalPower;
    }
    
    action def ReceiveCommands {
        in commandSignal : RadioSignal;
        out commands : CommandData;
    }
    
    action def TransmitTelemetry {
        in telemetry : TelemetryData;
        out telemetrySignal : RadioSignal;
    }
    
    action def AcquireScience {
        out scienceData : ScienceData;
    }
    
    action def DetermineAttitude {
        out attitudeData : AttitudeData;
    }
    
    action def ControlAttitude {
        in targetAttitude : AttitudeData;
        in currentAttitude : AttitudeData;
    }
    
    action def NavigateToTarget {
        in targetPosition : NavigationData;
        in currentPosition : NavigationData;
    }
    
    action def ProcessCommands {
        in commands : CommandData;
        out systemActions : CommandData;
    }
    
    action performSpacecraftMission : PerformSpacecraftMission;
    
    action def PerformSpacecraftMission {
        first start;
        then merge missionLoop;
        
        action generatePower : GeneratePower {
            out powerOutput : ElectricalPower;
        }
        
        then action receiveCommands : ReceiveCommands {
            in commandSignal : RadioSignal;
            out commands : CommandData;
        }
        
        then action processCommands : ProcessCommands {
            in commands = receiveCommands.commands;
            out systemActions : CommandData;
        }
        
        then action determineAttitude : DetermineAttitude {
            out attitudeData : AttitudeData;
        }
        
        then action controlAttitude : ControlAttitude {
            in targetAttitude : AttitudeData;
            in currentAttitude = determineAttitude.attitudeData;
        }
        
        then action navigateToTarget : NavigateToTarget {
            in targetPosition : NavigationData;
            in currentPosition : NavigationData;
        }
        
        then action acquireScience : AcquireScience {
            out scienceData : ScienceData;
        }
        
        then action transmitTelemetry : TransmitTelemetry {
            in telemetry : TelemetryData;
            out telemetrySignal : RadioSignal;
        }
        
        then missionLoop;
    }
    
    part def RoboticSpacecraft {
        attribute totalMass : ISQ::MassValue;
        attribute missionDuration : ISQ::TimeValue;
        attribute currentPhase : MissionPhase;
        
        perform action spacecraftMission[*] ordered references performSpacecraftMission;
        
        part powerSubsystem : PowerSubsystem {
            perform performSpacecraftMission.generatePower;
        }
        
        part commSubsystem : CommunicationSubsystem {
            perform performSpacecraftMission.receiveCommands;
            perform performSpacecraftMission.transmitTelemetry;
        }
        
        part attitudeControl : AttitudeControlSubsystem {
            perform performSpacecraftMission.determineAttitude;
            perform performSpacecraftMission.controlAttitude;
        }
        
        part propulsion : PropulsionSubsystem {
            perform performSpacecraftMission.navigateToTarget;
        }
        
        part scienceInstruments : ScienceInstrumentSubsystem {
            perform performSpacecraftMission.acquireScience;
        }
        
        part navigation : NavigationSubsystem;
        
        part commandDataHandling : CommandDataHandlingSubsystem {
            perform performSpacecraftMission.processCommands;
        }
        
        connection powerDistribution1 connect 
            powerSubsystem.powerOut to attitudeControl.powerIn;
        connection powerDistribution2 connect 
            powerSubsystem.powerOut to propulsion.powerIn;
        connection powerDistribution3 connect 
            powerSubsystem.powerOut to scienceInstruments.powerIn;
        connection powerDistribution4 connect 
            powerSubsystem.powerOut to navigation.powerIn;
        connection powerDistribution5 connect 
            powerSubsystem.powerOut to commandDataHandling.powerIn;
    }
    
    requirement def MissionRequirement;
    
    requirement <'REQ-001'> spacecraftMissionRequirement : MissionRequirement {
        doc /* The robotic spacecraft shall autonomously conduct scientific exploration 
                by collecting science data and transmitting it to Earth while maintaining 
                stable attitude control and power generation throughout the mission duration. */
        
        subject spacecraft : RoboticSpacecraft;
        
        require constraint powerGeneration {
            spacecraft.powerSubsystem.currentPowerLevel >= 0.0
        }
        
        require constraint attitudeStability {
            spacecraft.attitudeControl.currentAttitude == spacecraft.attitudeControl.targetAttitude
        }
        
        require constraint missionDurationConstraint {
            spacecraft.missionDuration >= 0.0[SI::s]
        }
    }
    
    requirement <'REQ-002'> massRequirement : MissionRequirement {
        doc /* The total mass of the robotic spacecraft shall not exceed the launch vehicle capacity. */
        
        subject spacecraft : RoboticSpacecraft;
        
        require constraint massLimit {
            spacecraft.totalMass <= 5000.0[SI::kg]
        }
    }
    
    part roboticSpacecraftInstance : RoboticSpacecraft {
        :>> totalMass = 4500.0[SI::kg];
        :>> missionDuration = 31536000.0[SI::s];
        
        part :>> powerSubsystem {
            :>> solarArrayArea = 25.0[SI::m^2];
            :>> batteryCapacity = 500000.0[SI::J];
        }
        
        part :>> commSubsystem {
            :>> antennaGain = 45.0;
            :>> transmitPower = 100.0[SI::W];
        }
        
        part :>> propulsion {
            :>> fuelMass = 500.0[SI::kg];
            :>> thrustCapacity = 500.0[SI::N];
        }
        
        part :>> scienceInstruments {
            :>> dataRate = 1000000.0;
        }
    }
}
