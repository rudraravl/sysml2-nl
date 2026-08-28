package WankelEngineSystem {
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        public import ISQ::*;
        public import ScalarValues::*;
        public import SI::*;

        alias Torque for ISQ::TorqueValue;
        alias RotationalSpeed for ISQ::AngularVelocityValue;
        alias Power for ISQ::PowerValue;
        alias Temperature for ISQ::TemperatureValue;
        alias Mass for ISQ::MassValue;
        alias Length for ISQ::LengthValue;
        alias Volume for ISQ::VolumeValue;
        alias Energy for ISQ::EnergyValue;
        alias VolumeFlowRate for ISQ::VolumeFlowRateValue;
        alias Duration for ISQ::DurationValue;
        alias Area for ISQ::AreaValue;
        alias Force for ISQ::ForceValue;
        alias Pressure for ISQ::PressureValue;

        attribute <'rpm'> rpm : ISQ::AngularVelocityUnit;

        item def AirFuelMixture {
            attribute airFuelRatio : Real;
            attribute massFlowRate : Real;
        }
        item def ExhaustGas {
            attribute temperature : Temperature;
            attribute pressure : Pressure;
        }
        item def Coolant {
            attribute temperature : Temperature;
            attribute flowRate : VolumeFlowRate;
        }

        attribute def StartCmd;
        attribute def StopCmd;
        attribute def EngineStarted;
        attribute def EngineStopped;

        port def FuelPort { in mixture : AirFuelMixture; }
        port def ExhaustPort { out gas : ExhaustGas; }
        port def CoolantInPort { in coolant : Coolant; }
        port def CoolantOutPort { out coolant : Coolant; }
        port def ShaftPort { out torque : Torque; out speed : RotationalSpeed; }
        port def CmdPort { in startCmd : StartCmd; in stopCmd : StopCmd; }
        port def SparkPort { out sparkTrigger : Boolean; }
        port def RotorShaftPort { out tangentialForce : Force; }

        part def Housing {
            attribute chamberShape : String = "Epitrochoidal";
            attribute innerRadius : Length;
            attribute outerRadius : Length;
            attribute chamberVolume : Volume;
            port coolantIn : CoolantInPort;
            port coolantOut : CoolantOutPort;
            port fuelIn : FuelPort;
            port exhaustOut : ExhaustPort;
            port sparkPlug : SparkPort;
        }
        part def Rotor {
            attribute faceArea : Area;
            attribute mass : Mass;
            attribute apexSealWear : Real;
            port rotorToShaft : RotorShaftPort;
        }
        part def EccentricShaft {
            attribute length : Length;
            attribute eccentricity : Length;
            port output : ShaftPort;
        }
        part def IgnitionSystem {
            attribute sparkEnergy : Energy;
            attribute sparkTiming : Real;
            port sparkOut : SparkPort;
        }
        part def CoolingSystem {
            attribute targetTemp : Temperature;
            attribute coolantCapacity : Volume;
            attribute pumpSpeed : RotationalSpeed;
            port coolantIn : CoolantInPort;
            port coolantOut : CoolantOutPort;
        }
        part def WankelEngine {
            attribute mass : Mass;
            attribute operatingTemp : Temperature;
            attribute maxPower : Power;
            attribute ratedSpeed : RotationalSpeed;
            attribute thermalEfficiency : Real;
            attribute operatingHours : Duration;
            port fuelPort : FuelPort;
            port exhaustPort : ExhaustPort;
            port shaftPort : ShaftPort;
            port cmdPort : CmdPort;
            port coolantInPort : CoolantInPort;
            port coolantOutPort : CoolantOutPort;
            part housing : Housing;
            part rotors : Rotor[3];
            part shaft : EccentricShaft;
            part ignition : IgnitionSystem;
            part cooling : CoolingSystem;
            perform action generatePower;
            exhibit state engineStates;
        }

        action def Intake {
            in mixture : AirFuelMixture;
            out chamberMixture : AirFuelMixture;
        }
        action def Compression {
            in chamberMixture : AirFuelMixture;
            out compressedMixture : AirFuelMixture;
            out compressionPressure : Pressure;
        }
        action def CombustionExpansion {
            in compressedMixture : AirFuelMixture;
            in sparkCmd : Boolean;
            out exhaustGas : ExhaustGas;
            out rotorForce : Force;
        }
        action def Exhaust {
            in exhaustGas : ExhaustGas;
            out gas : ExhaustGas;
        }
        action def GeneratePower {
            in mixture : AirFuelMixture;
            out gas : ExhaustGas;
            out torque : Torque;
            out speed : RotationalSpeed;
        }

        requirement def EngineRequirement {
            subject engine : WankelEngine;
        }
        requirement def PowerRequirement :> EngineRequirement {
            doc /* The engine must deliver at least 180 kW at 8000 rpm. */
            attribute actualPower : Power;
            attribute actualSpeed : RotationalSpeed;
            attribute requiredPower : Power = 180 [kW];
            attribute requiredSpeed : RotationalSpeed = 8000 [rpm];
            require constraint { actualPower >= requiredPower }
            require constraint { actualSpeed == requiredSpeed }
        }
        requirement def EfficiencyRequirement :> EngineRequirement {
            doc /* The engine must maintain a thermal efficiency of at least 28%. */
            attribute actualEfficiency : Real;
            attribute requiredEfficiency : Real = 0.28;
            require constraint { actualEfficiency >= requiredEfficiency }
        }
        requirement def ReliabilityRequirement :> EngineRequirement {
            doc /* The engine must operate reliably for at least 5000 hours before overhaul. */
            attribute actualTime : Duration;
            attribute requiredTime : Duration = 5000 [h];
            require constraint { actualTime >= requiredTime }
        }
    }

    package Usages {
        private import Definitions::*;
        private import ISQ::*;
        private import SI::*;
        private import ScalarValues::*;

        part wankelEngine : WankelEngine {
            attribute maxPower : Power = 180 [kW];
            attribute ratedSpeed : RotationalSpeed = 8000 [rpm];
            attribute thermalEfficiency : Real = 0.28;
            attribute operatingHours : Duration = 5000 [h];

            part housing : Housing {
                attribute chamberShape = "Epitrochoidal";
            }
            part rotors : Rotor[3];
            part shaft : EccentricShaft;
            part ignition : IgnitionSystem;
            part cooling : CoolingSystem;

            connect fuelPort to housing.fuelIn;
            connect housing.exhaustOut to exhaustPort;
            connect shaft.output to shaftPort;
            connect coolantInPort to cooling.coolantIn;
            connect cooling.coolantOut to housing.coolantIn;
            connect housing.coolantOut to coolantOutPort;
            connect ignition.sparkOut to housing.sparkPlug;

            action generatePower : GeneratePower {
                in mixture : AirFuelMixture = fuelPort.mixture;
                out gas : ExhaustGas;
                out torque : Torque;
                out speed : RotationalSpeed;

                action intake : Intake {
                    in mixture = generatePower::mixture;
                    out chamberMixture : AirFuelMixture;
                }
                flow intake.chamberMixture to compression.chamberMixture;
                action compression : Compression {
                    in chamberMixture : AirFuelMixture;
                    out compressedMixture : AirFuelMixture;
                    out compressionPressure : Pressure;
                }
                flow compression.compressedMixture to combustionExpansion.compressedMixture;
                action combustionExpansion : CombustionExpansion {
                    in compressedMixture : AirFuelMixture;
                    in sparkCmd : Boolean = true;
                    out exhaustGas : ExhaustGas;
                    out rotorForce : Force;
                }
                flow combustionExpansion.exhaustGas to exhaust.exhaustGas;
                action exhaust : Exhaust {
                    in exhaustGas : ExhaustGas;
                    out gas : ExhaustGas;
                }
                bind exhaust.gas to generatePower::gas;

                first start;
                then intake;
                then compression;
                then combustionExpansion;
                then exhaust;
                then done;
            }

            bind generatePower.gas to exhaustPort.gas;
            bind generatePower.torque to shaftPort.torque;
            bind generatePower.speed to shaftPort.speed;

            exhibit state engineStates {
                state off;
                state starting;
                state running {
                    do generatePower;
                }
                state stopping;
                transition off_to_starting
                    first off
                    accept startCmd : StartCmd via cmdPort
                    then starting;
                transition starting_to_running
                    first starting
                    accept engineStarted : EngineStarted
                    then running;
                transition running_to_stopping
                    first running
                    accept stopCmd : StopCmd via cmdPort
                    then stopping;
                transition stopping_to_off
                    first stopping
                    accept engineStopped : EngineStopped
                    then off;
            }
        }

        requirement powerReq : PowerRequirement {
            subject engine = wankelEngine;
            attribute actualPower = wankelEngine.maxPower;
            attribute actualSpeed = wankelEngine.ratedSpeed;
        }
        requirement efficiencyReq : EfficiencyRequirement {
            subject engine = wankelEngine;
            attribute actualEfficiency = wankelEngine.thermalEfficiency;
        }
        requirement reliabilityReq : ReliabilityRequirement {
            subject engine = wankelEngine;
            attribute actualTime = wankelEngine.operatingHours;
        }
    }
}
