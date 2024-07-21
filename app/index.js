import fs from "fs"
import path from "path"
import url from "url"
import XLSX from "xlsx"

const convertExcelDate = excelDate => {
  const date = new Date((excelDate - 25569) * 86400 * 1000)
  const day = String(date.getUTCDate()).padStart(2, "0")
  const month = String(date.getUTCMonth() + 1).padStart(2, "0")
  const year = date.getUTCFullYear()
  return `${month}/${day}/${year}` // Inverser jour et mois ici
}

const __filename = url.fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Lire le fichier CSV
const csvFilePath = path.join(__dirname, "in.csv")
const fileContent = fs.readFileSync(csvFilePath, "utf8")

// Convertir le contenu CSV en workbook
const workbook = XLSX.read(fileContent, { type: "string" })

// Accéder à la première feuille du workbook
const worksheet = workbook.Sheets[workbook.SheetNames[0]]

// Convertir la feuille en JSON (optionnel)
const jsonData = XLSX.utils.sheet_to_json(worksheet, { raw: true })

jsonData.forEach(item => {
  if (typeof item.formattedDate === "number") {
    item.formattedDate = convertExcelDate(item.formattedDate)
  }
})

const groupedData = jsonData.reduce((acc, obj) => {
  const sessionID = obj.SessionID
  if (!acc[sessionID]) {
    acc[sessionID] = []
  }
  acc[sessionID].push(obj)
  return acc
}, {})

// console.log(groupedData["07912340-1f8c-4d4d-8921-24c258ea8709"])
// console.log(groupedData["ed73e2a7-8f8a-493c-9388-c7cc4714b0ad"])

// Fonction pour appliquer la logique de série
const applySerieLogic = sessionData => {
  let serie = 0
  let vie = 2
  const datesMap = {}

  return sessionData.map((item, index) => {
    const date = item.formattedDate
    if (!datesMap[date]) {
      datesMap[date] = {
        level1Count: 0,
        level2Count: 0,
        allongeTrueAssisTrue: false,
        allongeTrueAssisFalse: false,
        allongeFalseAssisTrue: false,
        serieIncremented: false,
        conditionsMet: false,
        vieDecremented: false,
      }
    }

    const dateInfo = datesMap[date]

    if (item.Niveau === 1) {
      dateInfo.level1Count += 1
    }

    if (item.Niveau === 2) {
      dateInfo.level2Count += 1
    }

    if (item.Allonge === "True" && item.Assis === "True") {
      dateInfo.allongeTrueAssisTrue = true
    }

    if (item.Allonge === "True" && item.Assis === "False") {
      dateInfo.allongeTrueAssisFalse = true
    }

    if (item.Allonge === "False" && item.Assis === "True") {
      dateInfo.allongeFalseAssisTrue = true
    }

    if (
      (dateInfo.level1Count >= 2 || dateInfo.level2Count >= 1) &&
      (dateInfo.allongeTrueAssisTrue ||
        (dateInfo.allongeTrueAssisFalse && dateInfo.allongeFalseAssisTrue))
    ) {
      dateInfo.conditionsMet = true
    }

    if (index > 0) {
      const previousDate = sessionData[index - 1].formattedDate
      const previousDateInfo = datesMap[previousDate]

      if (
        previousDateInfo &&
        previousDateInfo.conditionsMet &&
        dateInfo.conditionsMet &&
        !dateInfo.serieIncremented
      ) {
        serie += 1
        dateInfo.serieIncremented = true // Reset to avoid multiple increments on the same day
      }
    }

    if (
      !dateInfo.conditionsMet &&
      !dateInfo.vieDecremented &&
      (index === sessionData.length - 1 || sessionData[index + 1].formattedDate !== date)
    ) {
      vie -= 1 // Perd une vie si les conditions ne sont pas remplies
      if (vie <= 0) {
        serie = 0 // Réinitialise la série si toutes les vie sont perdues
        vie = 2 // Réinitialise les vie à 2
      }
      dateInfo.vieDecremented = true // Empêche les vies d'être diminuées plusieurs fois dans la même journée
    }

    return { ...item, vie, serie }
  })
}

// Appliquer la logique de série à chaque groupe
Object.keys(groupedData).forEach(sessionID => {
  const sessionData = groupedData[sessionID]
  const updatedSessionData = applySerieLogic(sessionData)
  groupedData[sessionID] = updatedSessionData
})

let csvContent = "Date,Niveau,Allonge,Assis,SessionID,formattedDate,vie,serie\n"

Object.keys(groupedData).forEach(sessionID => {
  const sessionData = groupedData[sessionID]

  sessionData.forEach(item => {
    const row = [
      item.Date,
      item.Niveau,
      item.Allonge,
      item.Assis,
      item.SessionID,
      item.formattedDate,
      item.vie,
      item.serie,
    ].join(",")
    csvContent += row + "\n"
  })
})

// Écrire le contenu CSV dans un nouveau fichier
const outputCsvFilePath = path.join(__dirname, "out.csv")
fs.writeFileSync(outputCsvFilePath, csvContent)

console.log("Le fichier out.csv a été créé avec succès.")
