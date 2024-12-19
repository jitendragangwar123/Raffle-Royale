"use client";
import { useState, useEffect } from "react";
import { useAccount, useReadContract, useWatchContractEvent } from "wagmi";
import { RAFFLE_ABI, RAFFLE_ADDRESS } from "../../../constants/index";
import { ethers } from "ethers";
import toast from "react-hot-toast";

export default function RaffleDetails() {
  const [raffleState, setRaffleState] = useState<string | null>(null);
  const [numPlayers, setNumPlayers] = useState<number>(0);
  const [lastWinner, setLastWinner] = useState<string | null>(null);
  const [interval, setInterval] = useState<number>(0);
  const [entranceFee, setEntranceFee] = useState<string>("");
  const [amount, setAmount] = useState<string>("");
  const [isProcessing, setIsProcessing] = useState<boolean>(false);
  const { isConnected } = useAccount();

  const { data: state } = useReadContract({
    abi: RAFFLE_ABI,
    address: RAFFLE_ADDRESS,
    functionName: "getRaffleState",
  });

  const { data: players } = useReadContract({
    abi: RAFFLE_ABI,
    address: RAFFLE_ADDRESS,
    functionName: "getNumberOfPlayers",
  });

  const { data: winner } = useReadContract({
    abi: RAFFLE_ABI,
    address: RAFFLE_ADDRESS,
    functionName: "getRecentWinner",
  });

  const { data: intervalData } = useReadContract({
    abi: RAFFLE_ABI,
    address: RAFFLE_ADDRESS,
    functionName: "getInterval",
  });

  const { data: entranceFeeData } = useReadContract({
    abi: RAFFLE_ABI,
    address: RAFFLE_ADDRESS,
    functionName: "getEntranceFee",
  });

  useWatchContractEvent({
    address: RAFFLE_ADDRESS,
    abi: RAFFLE_ABI,
    eventName: "RaffleEnter",
    onLogs: (playerAddress) => {
      setNumPlayers((prev) => prev + 1);
    },
  });

  useEffect(() => {
    if (state !== undefined) {
      setRaffleState(state === 0 ? "Open" : state === 1 ? "Calculating" : "Unknown");
    }
  }, [state]);

  useEffect(() => {
    if (players !== undefined) {
      setNumPlayers(Number(players));
    }
  }, [players]);

  useEffect(() => {
    if (winner !== undefined) {
      setLastWinner(winner ? String(winner) : null);
    }
  }, [winner]);

  useEffect(() => {
    if (intervalData !== undefined) {
      setInterval(Number(intervalData));
    }
  }, [intervalData]);

  useEffect(() => {
    if (entranceFeeData) {
      try {
        const value: any = typeof entranceFeeData === "object" && "toString" in entranceFeeData
          ? entranceFeeData.toString()
          : entranceFeeData;
        setEntranceFee(ethers.formatEther(value));
      } catch (error) {
        console.error("Error formatting entrance fee:", error);
        setEntranceFee("N/A");
      }
    } else {
      setEntranceFee("N/A");
    }
  }, [entranceFeeData]);

  const handleEnterRaffle = async () => {
    if (!isConnected) {
      toast.error("Please connect your wallet.");
      return;
    }

    if (!amount || parseFloat(amount) < parseFloat(entranceFee)) {
      toast.error("Please enter a valid amount.");
      return;
    }

    if (raffleState !== "Open") {
      toast.error("You can't enter in this raffle. Please wait for the result.");
      return;
    }

    try {
      setIsProcessing(true);
      const provider = new ethers.BrowserProvider((window as any).ethereum);
      const signer = await provider.getSigner();
      const raffleContract = new ethers.Contract(RAFFLE_ADDRESS, RAFFLE_ABI, signer);
      const value = ethers.parseEther(amount);
      toast.loading("Transaction sent. Waiting for confirmation...");
      const tx = await raffleContract.enterRaffle({ value });
      await tx.wait();
      toast.dismiss();
      toast.success("Entered the raffle successfully!");
      setAmount("");
    } catch (error: any) {
      toast.dismiss();
      console.error("Error entering raffle:", error);
      const errorMessage =
        error.reason || error.message || "Failed to enter the raffle.";
      toast.error(errorMessage);
    } finally {
      setIsProcessing(false);
    }
  };

  function RaffleDetail({ label, value }: { label: string; value: string | number }) {
    return (
      <p className="text-lg sm:text-xl mb-2">
        <span className="font-semibold">{label}:</span> {value}
      </p>
    );
  }

  function truncateAddress(address:any, start = 10, end = 10) {
    if (!address) return "";
    return `${address.slice(0, start)}...${address.slice(-end)}`;
  }
  

  return (
    <div className="relative flex flex-col lg:flex-col gap-10 items-center justify-center min-h-screen py-10 px-4 sm:px-10 font-arcade">
      <div className="flex flex-col items-center w-full lg:w-1/2">
        <h2 className="text-3xl sm:text-4xl font-bold text-gray-200 mb-6">Raffle Details</h2>
        <div className="bg-gradient-to-b from-yellow-300 to-red-500 p-6 sm:p-8 rounded-2xl shadow-lg w-full">
          <RaffleDetail label="Raffle State" value={raffleState || "Loading..."} />
          <RaffleDetail label="Number of Players" value={numPlayers} />
          <RaffleDetail label="Interval" value={`${interval} seconds`} />
          <RaffleDetail label="Entrance Fee" value={`${entranceFee} ETH`} />
          <RaffleDetail label="Last Winner" value={lastWinner ? truncateAddress(lastWinner) : "No winner yet"}  />
        </div>
      </div>

      <div className="flex flex-col items-center w-full lg:w-1/2">
        <h3 className="text-3xl sm:text-4xl font-bold text-gray-200 mb-6">Enter the Raffle</h3>
        <div className="bg-gradient-to-b from-yellow-300 to-red-500 p-6 sm:p-8 rounded-2xl shadow-lg w-full">
          <input
            type="number"
            placeholder="Enter amount in ETH"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="w-full px-4 py-2 border text-gray-400 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-blue-400"
          />
          <button
            onClick={handleEnterRaffle}
            className={`w-full mt-4 px-4 py-2 rounded-md text-white text-lg font-semibold ${isProcessing
              ? "bg-gray-500 cursor-not-allowed"
              : "bg-blue-600 hover:bg-blue-700"
              }`}
          >
            {isProcessing ? "Entering..." : "Enter"}
          </button>
        </div>
      </div>
    </div>
  );
}
