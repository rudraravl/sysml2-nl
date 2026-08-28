package 'Regional Electric Power Distribution Grid' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        attribute MW : PowerUnit = 1000000 * W;
        attribute kV : ElectricPotentialUnit = 1000 * V;

        item def Electricity {
            attribute voltage : ElectricPotentialValue;
            attribute current : ElectricCurrentValue;
            attribute power : PowerValue;
        }

        item def 'Trip Signal';
        item def 'Close Signal';
        item def 'Fault Detected';
        item def 'Fault Isolated';
        item def 'Restoration Complete';
        item def 'Reset';

        port def PowerPort {
            out item power : Electricity;
        }

        port def ControlPort {
            out item 'Trip Signal';
            out item 'Close Signal';
        }

        part def PowerGenerator {
            attribute ratedPower : PowerValue;
            port outPort : PowerPort;
            perform action generatePower : GeneratePower;
        }

        part def Transformer {
            attribute turnsRatio : Real;
            port inPort : ~PowerPort;
            port outPort : PowerPort;
        }

        part def StepUpTransformer :> Transformer {
            constraint { turnsRatio > 1 }
        }

        part def StepDownTransformer :> Transformer {
            constraint { turnsRatio < 1 }
        }

        part def TransmissionLine {
            attribute length : LengthValue;
            port inPort : ~PowerPort;
            port outPort : PowerPort;
        }

        part def VoltageRegulator {
            attribute targetVoltage : ElectricPotentialValue;
            port inPort : ~PowerPort;
            port outPort : PowerPort;
        }

        part def ServiceTransformer :> StepDownTransformer;

        part def LoadCenter {
            attribute demand : PowerValue;
            attribute loadType : String;
            port inPort : ~PowerPort;
        }

        part def CircuitBreaker {
            attribute ratedCurrent : ElectricCurrentValue;
            attribute isOpen : Boolean = false;
            port inPort : ~PowerPort;
            port outPort : PowerPort;
            port controlPort : ~ControlPort;
            exhibit state 'breaker states' {
                entry; then breakerClosed;
                state breakerClosed;
                accept 'Trip Signal' then breakerOpen;
                state breakerOpen;
                accept 'Close Signal' then breakerClosed;
            }
        }

        part def ProtectionRelay {
            attribute ratedThreshold : ElectricCurrentValue;
            attribute measuredCurrent : ElectricCurrentValue;
            port monitorPort : ~PowerPort;
            port controlPort : ControlPort;
            exhibit state 'relay states' {
                entry; then normal;
                state normal;
                accept when measuredCurrent > ratedThreshold
                    do send new 'Trip Signal'() to controlPort
                    then tripped;
                state tripped;
                accept 'Reset' then normal;
            }
        }

        part def DistributionSubstation {
            part stepDownTransformer : StepDownTransformer;
            part mainBreaker : CircuitBreaker;
            part protectionRelay : ProtectionRelay;
            port inPort : ~PowerPort;
            port feederOutPort1 : PowerPort;
            port feederOutPort2 : PowerPort;
            port feederOutPort3 : PowerPort;

            connect inPort to stepDownTransformer.inPort;
            connect stepDownTransformer.outPort to mainBreaker.inPort;
            connect mainBreaker.outPort to feederOutPort1;
            connect mainBreaker.outPort to feederOutPort2;
            connect mainBreaker.outPort to feederOutPort3;
            connect stepDownTransformer.outPort to protectionRelay.monitorPort;
            connect protectionRelay.controlPort to mainBreaker.controlPort;
        }

        part def DistributionFeeder {
            part voltageRegulator : VoltageRegulator;
            port inPort : ~PowerPort;
            port outPort : PowerPort;

            connect inPort to voltageRegulator.inPort;
            connect voltageRegulator.outPort to outPort;
        }

        part def GridControlSystem {
            attribute totalDemand : PowerValue;
            attribute generationCapacity : PowerValue;
            exhibit state 'grid operation' {
                entry; then 'normal operation';
                state 'normal operation' {
                    entry 'calculate total demand';
                    do 'balance load';
                }
                accept 'Fault Detected' then 'fault handling';
                state 'fault handling' {
                    entry; then 'isolate fault';
                    state 'isolate fault' {
                        do 'isolate fault';
                    }
                    accept 'Fault Isolated' then 'reconfigure network';
                    state 'reconfigure network' {
                        do 'reroute power';
                    }
                }
                accept 'Restoration Complete' then 'normal operation';
            }
            action 'calculate total demand';
            action 'balance load';
            action 'isolate fault';
            action 'reroute power';
        }

        action def GeneratePower;
    }

    package Requirements {
        private import Definitions::*;

        requirement def PowerDeliveryRequirement {
            attribute deliveredPower : PowerValue;
            attribute requiredPower : PowerValue;
            require constraint { deliveredPower >= requiredPower }
        }

        requirement def VoltageStabilityRequirement {
            attribute measuredVoltage : ElectricPotentialValue;
            attribute nominalVoltage : ElectricPotentialValue;
            require constraint { measuredVoltage >= 0.95 * nominalVoltage and measuredVoltage <= 1.05 * nominalVoltage }
        }

        requirement def FaultIsolationRequirement {
            attribute isolationTime : Real;
            attribute maxIsolationTime : Real = 0.1;
            require constraint { isolationTime <= maxIsolationTime }
        }

        requirement def LoadBalancingRequirement {
            attribute feederLoad : PowerValue;
            attribute maxFeederCapacity : PowerValue;
            require constraint { feederLoad <= maxFeederCapacity }
        }
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;

        part regionalGrid {
            part generator : PowerGenerator {
                :>> ratedPower = 500 [MW];
            }
            part stepUpTransformer : StepUpTransformer {
                :>> turnsRatio = 100;
            }
            part transmissionLine : TransmissionLine;
            part substation : DistributionSubstation;

            part feeder1 : DistributionFeeder;
            part feeder2 : DistributionFeeder;
            part feeder3 : DistributionFeeder;

            part serviceTransformer1 : ServiceTransformer;
            part serviceTransformer2 : ServiceTransformer;
            part serviceTransformer3 : ServiceTransformer;

            part industrialLoad : LoadCenter {
                :>> loadType = "Industrial";
                :>> demand = 100 [MW];
            }
            part commercialLoad : LoadCenter {
                :>> loadType = "Commercial";
                :>> demand = 50 [MW];
            }
            part residentialLoad : LoadCenter {
                :>> loadType = "Residential";
                :>> demand = 20 [MW];
            }

            part controlSystem : GridControlSystem {
                :>> generationCapacity = 500 [MW];
                :>> totalDemand = 170 [MW];
            }

            connect generator.outPort to stepUpTransformer.inPort;
            connect stepUpTransformer.outPort to transmissionLine.inPort;
            connect transmissionLine.outPort to substation.inPort;

            connect substation.feederOutPort1 to feeder1.inPort;
            connect substation.feederOutPort2 to feeder2.inPort;
            connect substation.feederOutPort3 to feeder3.inPort;

            connect feeder1.outPort to serviceTransformer1.inPort;
            connect feeder2.outPort to serviceTransformer2.inPort;
            connect feeder3.outPort to serviceTransformer3.inPort;

            connect serviceTransformer1.outPort to industrialLoad.inPort;
            connect serviceTransformer2.outPort to commercialLoad.inPort;
            connect serviceTransformer3.outPort to residentialLoad.inPort;

            requirement powerDeliveryReq : PowerDeliveryRequirement {
                :>> deliveredPower = generator.ratedPower;
                :>> requiredPower = 170 [MW];
            }
            satisfy powerDeliveryReq;

            requirement voltageStabilityReq : VoltageStabilityRequirement {
                :>> measuredVoltage = 34.5 [kV];
                :>> nominalVoltage = 34.5 [kV];
            }
            satisfy voltageStabilityReq;

            requirement faultIsolationReq : FaultIsolationRequirement {
                :>> isolationTime = 0.05;
            }
            satisfy faultIsolationReq;

            requirement loadBalancingReq : LoadBalancingRequirement {
                :>> feederLoad = 100 [MW];
                :>> maxFeederCapacity = 200 [MW];
            }
            satisfy loadBalancingReq;
        }
    }
}
