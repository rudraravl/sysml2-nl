package 'GasTurbineEngineSystem' {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ISQ::TorqueValue;
    private import ISQ::PressureValue;
    private import ISQ::TemperatureValue;
    private import ISQ::MassFlowRateValue;
    private import ISQ::AngularVelocityValue;
    private import ISQ::PowerValue;
    
    alias Torque for ISQ::TorqueValue;
    alias Pressure for ISQ::PressureValue;
    alias Temperature for ISQ::TemperatureValue;
    alias MassFlowRate for ISQ::MassFlowRateValue;
    alias RotationalSpeed for ISQ::AngularVelocityValue;
    alias Power for ISQ::PowerValue;
    
    package Definitions {
        item def Air {
            attribute pressure : Pressure;
            attribute temperature : Temperature;
            attribute massFlowRate : MassFlowRate;
        }
        item def CompressedAir {
            attribute pressure : Pressure;
            attribute temperature : Temperature;
            attribute massFlowRate : MassFlowRate;
        }
        item def Fuel {
            attribute massFlowRate : MassFlowRate;
            attribute pressure : Pressure;
        }
        item def CombustionGas {
            attribute pressure : Pressure;
            attribute temperature : Temperature;
            attribute massFlowRate : MassFlowRate;
        }
        item def ExhaustGas {
            attribute pressure : Pressure;
            attribute temperature : Temperature;
            attribute massFlowRate : MassFlowRate;
        }

        port def AirPort {
            out item air : Air;
        }
        port def CompressedAirPort {
            out item compressedAir : CompressedAir;
        }
        port def FuelPort {
            out item fuel : Fuel;
        }
        port def CombustionGasPort {
            out item gas : CombustionGas;
        }
        port def ExhaustGasPort {
            out item exhaustGas : ExhaustGas;
            out exhaustTemp : Temperature;
        }
        port def MechanicalPort {
            out torque : Torque;
            out speed : RotationalSpeed;
            out power : Power;
        }
        port def SensorDataPort {
            out speed : RotationalSpeed;
            out power : Power;
            out temp : Temperature;
        }
        port def FuelControlPort {
            out fuelCmd : MassFlowRate;
        }

        action def CompressAir {
            in air : Air;
            in torque : Torque;
            in speed : RotationalSpeed;
            in power : Power;
            out compressedAir : CompressedAir;
        }
        action def BurnFuel {
            in compressedAir : CompressedAir;
            in fuel : Fuel;
            out combustionGas : CombustionGas;
        }
        action def ExpandGas {
            in combustionGas : CombustionGas;
            out exhaustGas : ExhaustGas;
            out exhaustTemp : Temperature;
            out torque : Torque;
            out speed : RotationalSpeed;
            out power : Power;
        }
        action def TransferPower {
            in turbineTorque : Torque;
            in turbineSpeed : RotationalSpeed;
            in turbinePower : Power;
            out compressorTorque : Torque;
            out compressorSpeed : RotationalSpeed;
            out compressorPower : Power;
            out netTorque : Torque;
            out netSpeed : RotationalSpeed;
            out netPower : Power;
        }
        action def PumpFuel {
            in fuelCmd : MassFlowRate;
            in fuel : Fuel;
            out fuel : Fuel;
        }
        action def MonitorAndAdjust {
            in speed : RotationalSpeed;
            in power : Power;
            in temp : Temperature;
            out fuelCmd : MassFlowRate;
        }

        part def Compressor {
            port airIn : ~AirPort;
            port airOut : CompressedAirPort;
            port mechIn : ~MechanicalPort;
            
            perform action compress : CompressAir {
                in air = airIn.air;
                in torque = mechIn.torque;
                in speed = mechIn.speed;
                in power = mechIn.power;
                out compressedAir = airOut.compressedAir;
            }
        }
        
        part def CombustionChamber {
            port airIn : ~CompressedAirPort;
            port fuelIn : ~FuelPort;
            port gasOut : CombustionGasPort;
            
            perform action burn : BurnFuel {
                in compressedAir = airIn.compressedAir;
                in fuel = fuelIn.fuel;
                out combustionGas = gasOut.gas;
            }
        }
        
        part def Turbine {
            port gasIn : ~CombustionGasPort;
            port gasOut : ExhaustGasPort;
            port mechOut : MechanicalPort;
            
            perform action expand : ExpandGas {
                in combustionGas = gasIn.gas;
                out exhaustGas = gasOut.exhaustGas;
                out exhaustTemp = gasOut.exhaustTemp;
                out torque = mechOut.torque;
                out speed = mechOut.speed;
                out power = mechOut.power;
            }
        }
        
        part def Shaft {
            port turbineSide : ~MechanicalPort;
            port compressorSide : MechanicalPort;
            port loadSide : MechanicalPort;
            
            perform action transfer : TransferPower {
                in turbineTorque = turbineSide.torque;
                in turbineSpeed = turbineSide.speed;
                in turbinePower = turbineSide.power;
                out compressorTorque = compressorSide.torque;
                out compressorSpeed = compressorSide.speed;
                out compressorPower = compressorSide.power;
                out netTorque = loadSide.torque;
                out netSpeed = loadSide.speed;
                out netPower = loadSide.power;
            }
        }
        
        part def FuelSystem {
            port fuelIn : ~FuelPort;
            port fuelOut : FuelPort;
            port controlIn : ~FuelControlPort;
            
            perform action pump : PumpFuel {
                in fuelCmd = controlIn.fuelCmd;
                in fuel = fuelIn.fuel;
                out fuel = fuelOut.fuel;
            }
        }
        
        part def ControlSystem {
            port sensorIn : ~SensorDataPort;
            port fuelCmdOut : FuelControlPort;
            attribute startSignal : Boolean;
            attribute stopSignal : Boolean;
            
            perform action monitor : MonitorAndAdjust {
                in speed = sensorIn.speed;
                in power = sensorIn.power;
                in temp = sensorIn.temp;
                out fuelCmd = fuelCmdOut.fuelCmd;
            }
            
            stateMachine control {
                state Off;
                state Starting;
                state Running;
                state Stopping;
                
                transition off_to_starting from Off to Starting when startSignal;
                transition starting_to_running from Starting to Running;
                transition running_to_stopping from Running to Stopping when stopSignal;
                transition stopping_to_off from Stopping to Off;
            }
        }

        requirement def PrimaryFunctionReq {
            doc /* The gas turbine engine shall continuously convert chemical energy from fuel into rotational mechanical power. */
        }
        requirement def ControlSystemReq {
            doc /* The control system shall monitor parameters and adjust fuel flow to maintain stable operation. */
        }

        part def GasTurbineEngine {
            satisfy primaryFunction : PrimaryFunctionReq;
            satisfy controlReq : ControlSystemReq;
            
            port airIntake : AirPort;
            port fuelIntake : FuelPort;
            port exhaust : ~ExhaustGasPort;
            port powerOutput : ~MechanicalPort;
            attribute startCmd : Boolean;
            attribute stopCmd : Boolean;
            
            part compressor : Compressor;
            part combustionChamber : CombustionChamber;
            part turbine : Turbine;
            part shaft : Shaft;
            part fuelSystem : FuelSystem;
            part controlSystem : ControlSystem;
            
            flow of air : Air from airIntake.air to compressor.airIn.air;
            flow of compressedAir : CompressedAir from compressor.airOut.compressedAir to combustionChamber.airIn.compressedAir;
            flow of fuel : Fuel from fuelIntake.fuel to fuelSystem.fuelIn.fuel;
            flow of fuel : Fuel from fuelSystem.fuelOut.fuel to combustionChamber.fuelIn.fuel;
            flow of gas : CombustionGas from combustionChamber.gasOut.gas to turbine.gasIn.gas;
            flow of exhaustGas : ExhaustGas from turbine.gasOut.exhaustGas to exhaust.exhaustGas;
            flow of exhaustTemp : Temperature from turbine.gasOut.exhaustTemp to exhaust.exhaustTemp;
            
            flow of torque : Torque from turbine.mechOut.torque to shaft.turbineSide.torque;
            flow of speed : RotationalSpeed from turbine.mechOut.speed to shaft.turbineSide.speed;
            flow of power : Power from turbine.mechOut.power to shaft.turbineSide.power;
            
            flow of torque : Torque from shaft.compressorSide.torque to compressor.mechIn.torque;
            flow of speed : RotationalSpeed from shaft.compressorSide.speed to compressor.mechIn.speed;
            flow of power : Power from shaft.compressorSide.power to compressor.mechIn.power;
            
            flow of torque : Torque from shaft.loadSide.torque to powerOutput.torque;
            flow of speed : RotationalSpeed from shaft.loadSide.speed to powerOutput.speed;
            flow of power : Power from shaft.loadSide.power to powerOutput.power;
            
            flow of speed : RotationalSpeed from shaft.loadSide.speed to controlSystem.sensorIn.speed;
            flow of power : Power from shaft.loadSide.power to controlSystem.sensorIn.power;
            flow of temp : Temperature from turbine.gasOut.exhaustTemp to controlSystem.sensorIn.temp;
            
            flow of fuelCmd : MassFlowRate from controlSystem.fuelCmdOut.fuelCmd to fuelSystem.controlIn.fuelCmd;
            
            bind controlSystem.startSignal = startCmd;
            bind controlSystem.stopSignal = stopCmd;
        }
    }

    package Usages {
        part myEngine : GasTurbineEngine;
    }
}
