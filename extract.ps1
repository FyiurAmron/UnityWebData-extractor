#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string]$UnityWebDataFile
)

$SIGNATURE = "UnityWebData1.0"
$EXTRACTION_DIR = "extracted"

function Read-Int32LE {
    param ([System.IO.BinaryReader]$Reader)
    return [BitConverter]::ToInt32($Reader.ReadBytes(4), 0)
}

function Read-String {
    param (
        [System.IO.BinaryReader]$Reader,
        [int]$Length = -1
    )

    if ($Length -ge 0) {
        $bytes = $Reader.ReadBytes($Length)
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    } else {
        $bytes = New-Object System.Collections.Generic.List[byte]
        while (($b = $Reader.ReadByte()) -ne 0) {
            $bytes.Add($b)
        }
        return [System.Text.Encoding]::UTF8.GetString($bytes.ToArray())
    }
}

$fs = [System.IO.File]::OpenRead($UnityWebDataFile)
$br = New-Object System.IO.BinaryReader($fs)

try {
    $signature = Read-String $br
    $headerLength = Read-Int32LE $br

    if ($signature -ne $SIGNATURE) {
        throw "Invalid signature '$signature'"
    }

    $blobs = @()

    while ($fs.Position -lt $headerLength) {
        $offset = Read-Int32LE $br
        $size   = Read-Int32LE $br
        $namez  = Read-Int32LE $br
        $name   = Read-String $br $namez

        $blobs += [pscustomobject]@{
            Name   = $name
            Offset = $offset
            Size   = $size
        }
    }

    if ($fs.Position -gt $headerLength) {
        throw "Read past header length, invalid header"
    }

    foreach ($blob in $blobs) {
        $fs.Seek($blob.Offset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $data = $br.ReadBytes($blob.Size)

        if ($data.Length -lt $blob.Size) {
            throw "Invalid size or offset, reading past file"
        }

        Write-Host ("extracting @ {0}:`t{1} ({2})" -f $blob.Offset, $blob.Name, $blob.Size)

        $dest = Join-Path $EXTRACTION_DIR $blob.Name
        $dir  = Split-Path $dest -Parent
        if ($dir) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }

        [System.IO.File]::WriteAllBytes($dest, $data)
    }
}
finally {
    $br.Close()
    $fs.Close()
}
