package CuriosityRoverModel {
    private import ISQ::*;
    private import ScalarValues::*;
    
    attribute def SigReceiveCommand;
    attribute def SigArrivedAtTarget;
    attribute def SigSampleAcquired;
    attribute def SigAnalysisComplete;
    attribute def SigCommunicationComplete;
    attribute def SigBatteryLow;
    attribute def SigBatteryCharged;
    attribute def SigHazardDetected;
    
    item def RockSample;
    item def ImageData;
    item def ScienceData;
    item def EngineeringData;
    item def CommandData;
    item def ElectricalPower;
    item def ThermalEnergy;
    
    port def PowerInPort { in power : ElectricalPower; }
    port def PowerOutPort { out power : ElectricalPower; }
    port def CmdInPort { in command : CommandData; }
    port def CmdOutPort { out command : CommandData; }
    port def DataInPort { in data : ScienceData; }
    port def DataOutPort { out data : ScienceData; }
    port def ImgOutPort { out image : ImageData; }
    port def ImgInPort { in image : ImageData; }
    port def SampleOutPort { out sample : RockSample; }
    port def SampleInPort { in sample : RockSample; }
    port def BatteryStatusOutPort { out chargeLevel : ScalarValues::Real; }
    port def BatteryStatusInPort { in chargeLevel : ScalarValues::Real; }
    port def ThermalOutPort { out heat : ThermalEnergy; }
    
    part def Wheel {
        attribute radius : ISQ::LengthValue;
        port torqueIn { in torque : ISQ::TorqueValue; }
        port speedOut { out speed : ISQ::SpeedValue; }
    }
    
    part def RockerBogieSuspension {
        part leftRocker;
        part rightRocker;
        part leftBogie;
        part rightBogie;
        part pivotJoint;
    }
    
    part def MobilitySubsystem {
        part wheels[6] : Wheel;
        part suspension : RockerBogieSuspension;
        port driveCmdPort : CmdInPort;
        port powerIn : PowerInPort;
        port positionOut { out position : EngineeringData; }
        perform action drive {
            in command : CommandData;
            first start;
            then action engageMotors;
            then action traverseTerrain;
            then done;
        }
    }
    
    part def HazardCamera {
        attribute fieldOfView : ScalarValues::Real;
        port imageOut : ImgOutPort;
        port powerIn : PowerInPort;
    }
    
    part def InertialMeasurementUnit {
        attribute orientation : ScalarValues::Real;
        port dataOut { out data : EngineeringData; }
        port powerIn : PowerInPort;
    }
    
    part def NavigationSubsystem {
        part hazardCameras[4] : HazardCamera;
        part imu : InertialMeasurementUnit;
        port cmdPort : CmdInPort;
        port powerIn : PowerInPort;
        port navDataOut { out navData : EngineeringData; }
        port driveCmdOut : CmdOutPort;
        perform action navigate {
            in command : CommandData;
            in images : ImageData;
            in imuData : EngineeringData;
            out driveCmd : CommandData;
            first start;
            then action assessTerrain;
            then action planPath;
            then action issueDriveCmd;
            then done;
        }
    }
    
    part def MMRTG {
        attribute outputPower : ISQ::PowerValue = 110;
        port powerOut : PowerOutPort;
        port thermalOut : ThermalOutPort;
        perform action generatePower {
            out power : ElectricalPower;
            first start;
            then action decayHeat;
            then action thermoelectricConversion;
            then done;
        }
    }
    
    part def BatteryPack {
        attribute capacity : ISQ::EnergyValue = 40000000;
        attribute chargeLevel : ScalarValues::Real = 1.0;
        port chargeIn : PowerInPort;
        port powerOut : PowerOutPort;
        port statusOut : BatteryStatusOutPort;
        perform action monitorCharge {
            out chargeLevel : ScalarValues::Real;
            first start;
            then action measureVoltage;
            then action computeCharge;
            then done;
        }
    }
    
    part def PowerManagementModule {
        port mmrtgInput : PowerInPort;
        port battery1Input : PowerInPort;
        port battery2Input : PowerInPort;
        port powerOutput : PowerOutPort;
        port statusIn : BatteryStatusInPort;
        port statusOut : BatteryStatusOutPort;
        port cmdIn : CmdInPort;
        perform action distributePower {
            in inputPower : ElectricalPower;
            in batteryStatus : ScalarValues::Real;
            out outputPower : ElectricalPower;
            first start;
            then action assessDemand;
            then action balanceLoad;
            then done;
        }
    }
    
    part def PowerSubsystem {
        part mmrtg : MMRTG;
        part battery1 : BatteryPack;
        part battery2 : BatteryPack;
        part powerMgmt : PowerManagementModule;
        port cmdIn : CmdInPort;
        port powerOut : PowerOutPort;
        port batteryStatusOut : BatteryStatusOutPort;
        
        connect mmrtg.powerOut to powerMgmt.mmrtgInput;
        connect battery1.powerOut to powerMgmt.battery1Input;
        connect battery2.powerOut to powerMgmt.battery2Input;
        connect powerMgmt.powerOutput to powerOut;
        connect powerMgmt.powerOutput to battery1.chargeIn;
        connect powerMgmt.powerOutput to battery2.chargeIn;
        connect battery1.statusOut to powerMgmt.statusIn;
        connect battery2.statusOut to powerMgmt.statusIn;
        connect powerMgmt.statusOut to batteryStatusOut;
    }
    
    part def Heater {
        attribute powerRating : ISQ::PowerValue;
        port powerIn : PowerInPort;
        port thermalOut : ThermalOutPort;
    }
    
    part def Radiator {
        port thermalOut : ThermalOutPort;
        perform action dissipateHeat {
            in heat : ThermalEnergy;
            first start;
            then action transferHeat;
            then done;
        }
    }
    
    part def ThermalControlSubsystem {
        part heaters[2] : Heater;
        part radiators[2] : Radiator;
        part controller;
        port cmdIn : CmdInPort;
        port powerIn : PowerInPort;
        port tempSensorIn { in temperature : ISQ::TemperatureValue; }
        port heatOut : ThermalOutPort;
        perform action regulateTemperature {
            in currentTemp : ISQ::TemperatureValue;
            out heat : ThermalEnergy;
            first start;
            then action readTemp;
            then action decideAction;
            then action activateHeaters;
            then done;
        }
    }
    
    part def MastCamera {
        attribute resolution : ScalarValues::Real;
        port cmdIn : CmdInPort;
        port powerIn : PowerInPort;
        port imageOut : ImgOutPort;
    }
    
    part def ChemCam {
        attribute laserPower : ISQ::PowerValue;
        port cmdIn : CmdInPort;
        port powerIn : PowerInPort;
        port dataOut : DataOutPort;
        perform action fireLaser {
            in target : CommandData;
            out data : ScienceData;
            first start;
            then action vaporizeRock;
            then action analyzePlasma;
            then done;
        }
    }
    
    part def Drill {
        port cmdIn : CmdInPort;
        port powerIn : PowerInPort;
        port sampleOut : SampleOutPort;
        perform action acquireSample {
            in cmd : CommandData;
            out sample : RockSample;
            first start;
            then action positionDrill;
            then action drillRock;
            then action collectPowder;
            then done;
        }
    }
    
    part def SampleAnalysisLab {
        port cmdIn : CmdInPort;
        port powerIn : PowerInPort;
        port sampleIn : SampleInPort;
        port dataOut : DataOutPort;
        perform action analyzeSample {
            in sample : RockSample;
            out data : ScienceData;
            first start;
            then action heatSample;
            then action collectGases;
            then action gasChromatography;
            then action massSpectrometry;
            then done;
        }
    }
    
    part def SciencePayload {
        part mastcam : MastCamera;
        part chemcam : ChemCam;
        part drill : Drill;
        part sam : SampleAnalysisLab;
        port cmdIn : CmdInPort;
        port powerIn : PowerInPort;
        port dataOut : DataOutPort;
        port imageOut : ImgOutPort;
        
        connect cmdIn to mastcam.cmdIn;
        connect cmdIn to chemcam.cmdIn;
        connect cmdIn to drill.cmdIn;
        connect cmdIn to sam.cmdIn;
        connect powerIn to mastcam.powerIn;
        connect powerIn to chemcam.powerIn;
        connect powerIn to drill.powerIn;
        connect powerIn to sam.powerIn;
        connect drill.sampleOut to sam.sampleIn;
        connect mastcam.imageOut to imageOut;
        connect chemcam.dataOut to dataOut;
        connect sam.dataOut to dataOut;
    }
    
    part def HighGainAntenna {
        attribute band : ScalarValues::String = "X-band";
        port dataIn : DataInPort;
        port cmdOut : CmdOutPort;
    }
    
    part def UHFAntenna {
        attribute band : ScalarValues::String = "UHF";
        port dataIn : DataInPort;
        port cmdOut : CmdOutPort;
    }
    
    part def CommunicationSubsystem {
        part highGainAntenna : HighGainAntenna;
        part uhfAntenna : UHFAntenna;
        port cmdIn : CmdInPort;
        port powerIn : PowerInPort;
        port dataIn : DataInPort;
        port cmdOut : CmdOutPort;
        port dataOut : DataOutPort;
        perform action transmitData {
            in data : ScienceData;
            first start;
            then action selectAntenna;
            then action encodeData;
            then action sendTransmission;
            then done;
        }
    }
    
    part def OnboardComputer {
        port cmdIn : CmdInPort;
        port cmdOut : CmdOutPort;
        port dataIn : DataInPort;
        port imgIn : ImgInPort;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
        port batteryStatusIn : BatteryStatusInPort;
        port navDataIn { in navData : EngineeringData; }
        perform action executeCommand {
            in cmd : CommandData;
            out data : ScienceData;
            first start;
            then action parseCmd;
            then action dispatchToSubsystems;
            then action collectResults;
            then done;
        }
    }
    
    part def CuriosityRover {
        attribute mass : ISQ::MassValue = 899;
        attribute landingSite : ScalarValues::String = "Gale Crater";
        attribute missionObjective : ScalarValues::String = "Assess past habitability of Mars";
        attribute operationalTempMin : ISQ::TemperatureValue = 233;
        attribute operationalTempMax : ISQ::TemperatureValue = 323;
        
        part mobility : MobilitySubsystem;
        part navigation : NavigationSubsystem;
        part power : PowerSubsystem;
        part thermal : ThermalControlSubsystem;
        part science : SciencePayload;
        part computer : OnboardComputer;
        part comm : CommunicationSubsystem;
        
        connect power.powerOut to mobility.powerIn;
        connect power.powerOut to navigation.powerIn;
        connect power.powerOut to thermal.powerIn;
        connect power.powerOut to science.powerIn;
        connect power.powerOut to computer.powerIn;
        connect power.powerOut to comm.powerIn;
        
        connect computer.cmdOut to mobility.driveCmdPort;
        connect computer.cmdOut to navigation.cmdPort;
        connect computer.cmdOut to power.cmdIn;
        connect computer.cmdOut to thermal.cmdIn;
        connect computer.cmdOut to science.cmdIn;
        connect computer.cmdOut to comm.cmdIn;
        
        connect comm.cmdOut to computer.cmdIn;
        connect computer.dataOut to comm.dataIn;
        connect science.dataOut to computer.dataIn;
        connect science.imageOut to computer.imgIn;
        connect mobility.positionOut to computer.navDataIn;
        connect navigation.navDataOut to computer.navDataIn;
        connect power.batteryStatusOut to computer.batteryStatusIn;
        connect navigation.driveCmdOut to mobility.driveCmdPort;
        
        state roverStates {
            entry; then idle;
            state idle;
            accept SigReceiveCommand then navigating;
            state navigating;
            accept SigArrivedAtTarget then sampling;
            accept SigHazardDetected then idle;
            state sampling;
            accept SigSampleAcquired then analyzing;
            state analyzing;
            accept SigAnalysisComplete then communicating;
            state communicating;
            accept SigCommunicationComplete then idle;
            transition navigating_charging
                first navigating
                accept SigBatteryLow
                then charging;
            transition sampling_charging
                first sampling
                accept SigBatteryLow
                then charging;
            transition analyzing_charging
                first analyzing
                accept SigBatteryLow
                then charging;
            state charging;
            accept SigBatteryCharged then idle;
        }
        
        perform action missionSequence {
            in command : CommandData;
            out result : ScienceData;
            first start;
            then action receiveCmd;
            then action driveToTarget;
            then action acquireRockSample;
            then action analyzeInLab;
            then action transmitToEarth;
            then done;
        }
    }
    
    requirement def RoverMissionRequirement {
        subject rover : CuriosityRover;
        text = "Explore Gale Crater and assess past habitability of Mars";
    }
    
    requirement def MobilityRequirement {
        subject rover : CuriosityRover;
        text = "The rover shall traverse rocky and sandy terrain using a six-wheeled rocker-bogie suspension";
    }
    
    requirement def PowerRequirement {
        subject rover : CuriosityRover;
        text = "The rover shall be powered by an MMRTG supplemented by two rechargeable battery packs";
    }
    
    requirement def ThermalRequirement {
        subject rover : CuriosityRover;
        text = "The rover shall maintain electronics within operational temperatures using heaters and radiators";
    }
    
    requirement def ScienceRequirement {
        subject rover : CuriosityRover;
        text = "The rover shall acquire and analyze rock samples to search for organic compounds";
    }
    
    requirement def CommunicationRequirement {
        subject rover : CuriosityRover;
        text = "The rover shall transmit science and engineering data to Earth via X-band and UHF antennas";
    }
    
    part curiosityRover : CuriosityRover;
    
    requirement curiosityMissionReq : RoverMissionRequirement {
        subject rover :> curiosityRover;
    }
    requirement curiosityMobilityReq : MobilityRequirement {
        subject rover :> curiosityRover;
    }
    requirement curiosityPowerReq : PowerRequirement {
        subject rover :> curiosityRover;
    }
    requirement curiosityThermalReq : ThermalRequirement {
        subject rover :> curiosityRover;
    }
    requirement curiosityScienceReq : ScienceRequirement {
        subject rover :> curiosityRover;
    }
    requirement curiosityCommReq : CommunicationRequirement {
        subject rover :> curiosityRover;
    }
}
