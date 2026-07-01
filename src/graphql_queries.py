_VIEWER_QUERY = """
query {
  Viewer {
    id
    name
    avatar { large }
    mediaListOptions {
      scoreFormat
    }
  }
}
"""

_ANIME_LIST_QUERY = """
query ($userId: Int) {
  MediaListCollection(userId: $userId, type: ANIME) {
    lists {
      entries {
        id
        status
        score
        progress
        repeat
        notes
        priority
        hiddenFromStatusLists
        private
        startedAt  { year month day }
        completedAt { year month day }
        updatedAt
        media {
          id
          title { userPreferred romaji english }
          format
          episodes
          coverImage { large }
          nextAiringEpisode {
            episode
            timeUntilAiring
          }
        }
      }
    }
  }
}
"""

_MANGA_LIST_QUERY = """
query ($userId: Int) {
  MediaListCollection(userId: $userId, type: MANGA) {
    lists {
      entries {
        id
        status
        score
        progress
        progressVolumes
        repeat
        notes
        priority
        hiddenFromStatusLists
        private
        startedAt  { year month day }
        completedAt { year month day }
        updatedAt
        media {
          id
          title { userPreferred romaji english }
          format
          chapters
          volumes
          coverImage { large }
        }
      }
    }
  }
}
"""

_SAVE_ANIME_ENTRY_MUTATION = """
mutation (
  $mediaId:              Int,
  $status:               MediaListStatus,
  $score:                Float,
  $progress:             Int,
  $repeat:               Int,
  $notes:                String,
  $priority:             Int,
  $hiddenFromStatusLists: Boolean,
  $private:              Boolean,
  $startedAt:            FuzzyDateInput,
  $completedAt:          FuzzyDateInput
) {
  SaveMediaListEntry(
    mediaId:              $mediaId,
    status:               $status,
    score:                $score,
    progress:             $progress,
    repeat:               $repeat,
    notes:                $notes,
    priority:             $priority,
    hiddenFromStatusLists: $hiddenFromStatusLists,
    private:              $private,
    startedAt:            $startedAt,
    completedAt:          $completedAt
  ) {
    id
    progress
    status
    score
  }
}
"""

_SAVE_MANGA_ENTRY_MUTATION = """
mutation (
  $mediaId:              Int,
  $status:               MediaListStatus,
  $score:                Float,
  $progress:             Int,
  $progressVolumes:      Int,
  $repeat:               Int,
  $notes:                String,
  $priority:             Int,
  $hiddenFromStatusLists: Boolean,
  $private:              Boolean,
  $startedAt:            FuzzyDateInput,
  $completedAt:          FuzzyDateInput
) {
  SaveMediaListEntry(
    mediaId:              $mediaId,
    status:               $status,
    score:                $score,
    progress:             $progress,
    progressVolumes:      $progressVolumes,
    repeat:               $repeat,
    notes:                $notes,
    priority:             $priority,
    hiddenFromStatusLists: $hiddenFromStatusLists,
    private:              $private,
    startedAt:            $startedAt,
    completedAt:          $completedAt
  ) {
    id
    progress
    progressVolumes
    status
    score
  }
}
"""

_DELETE_ANIME_ENTRY_MUTATION = """
mutation ($id: Int) {
  DeleteMediaListEntry(id: $id) {
    deleted
  }
}
"""

_DELETE_MANGA_ENTRY_MUTATION = """
mutation ($id: Int) {
  DeleteMediaListEntry(id: $id) {
    deleted
  }
}
"""

_TOGGLE_FAVOURITE_MUTATION = """
mutation ($animeId: Int) {
  ToggleFavourite(animeId: $animeId) {
    anime {
      nodes { id }
    }
  }
}
"""

_ANIME_PAGE_QUERY = """
query ($id: Int) {
  Media(id: $id, type: ANIME) {
    id
    title {
      romaji
      english
      native
      userPreferred
    }
    nextAiringEpisode {
      airingAt
      timeUntilAiring
      episode
    }
    format
    episodes
    duration
    status
    season
    seasonYear
    startDate {
      day
      month
      year
    }
    endDate {
      day
      month
      year
    }
    averageScore
    meanScore
    popularity
    favourites
    isFavourite
    studios {
      nodes {
        name
        isAnimationStudio
      }
    }
    source
    hashtag
    genres
    synonyms
    tags {
      name
      rank
      isMediaSpoiler
    }
    externalLinks {
      site
      url
    }
    bannerImage
    coverImage {
      large
    }
    description
    relations {
      edges {
        relationType(version: 2)
        node {
          id
          type
          format
          title {
            romaji
            english
          }
          coverImage {
            large
          }
          status
        }
      }
    }
    characters(sort: [RELEVANCE], perPage: 25) {
      edges {
        role
        node {
          id
          name {
            full
            native
          }
          image {
            large
          }
        }
      }
    }
    staff(sort: [RELEVANCE], perPage: 3) {
      edges {
        role
        node {
          id
          name {
            full
            native
          }
          image {
            large
          }
        }
      }
    }
    recommendations(sort: [RATING_DESC], perPage: 30) {
      nodes {
        mediaRecommendation {
          id
          title {
            english
            native
            romaji
          }
          coverImage {
            large
          }
        }
      }
    }
  }
}
"""

_CHARACTER_PAGE_QUERY = """
query ($id: Int) {
  Character (id: $id) {
    name {
      full
      native
      alternative
      alternativeSpoiler
      userPreferred
    }
    image { large }
    description
    age
    bloodType
    isFavourite
    isFavouriteBlocked
    gender
    dateOfBirth { day month year }
    siteUrl
    media {
      edges {
        node {
          id
          type
          title { english native romaji }
          coverImage { extraLarge }
        }
        voiceActors(sort: [RELEVANCE]) {
          id
          name { full native userPreferred }
          image { large }
          languageV2
        }
      }
    }
  }
}
"""

_TOGGLE_CHARACTER_FAVOURITE_MUTATION = """
mutation ($characterId: Int) {
  ToggleFavourite(characterId: $characterId) {
    characters {
      nodes { id }
    }
  }
}
"""

_STAFF_PAGE_QUERY = """
query ($id: Int) {
  Staff(id: $id) {
    name { full native alternative userPreferred }
    languageV2
    image { large }
    description
    primaryOccupations
    gender
    dateOfBirth { day month year }
    dateOfDeath { day month year }
    age
    yearsActive
    homeTown
    bloodType
    isFavourite
    isFavouriteBlocked
    siteUrl

    staffMedia(sort: [POPULARITY_DESC], perPage: 25, page: 1) {
      pageInfo { hasNextPage }
      edges {
        staffRole
        node {
          id
          type
          title { userPreferred english romaji }
          coverImage { large }
        }
      }
    }

    characters(sort: [FAVOURITES_DESC], perPage: 25, page: 1) {
      pageInfo { hasNextPage }
      edges {
        node {
          id
          name { userPreferred native }
          image { large }
        }
        media {
          id
          title { userPreferred english romaji }
          coverImage { large }
        }
      }
    }
  }
}
"""

_STAFF_PAGE_NEXT_QUERY = """
query ($id: Int, $mediaPage: Int, $charPage: Int) {
  Staff(id: $id) {
    staffMedia(sort: [POPULARITY_DESC], perPage: 25, page: $mediaPage) {
      pageInfo { hasNextPage }
      edges {
        staffRole
        node {
          id
          type
          title { userPreferred english romaji }
          coverImage { large }
        }
      }
    }
    characters(sort: [FAVOURITES_DESC], perPage: 25, page: $charPage) {
      pageInfo { hasNextPage }
      edges {
        node {
          id
          name { userPreferred native }
          image { large }
        }
        media {
          id
          title { userPreferred english romaji }
          coverImage { large }
        }
      }
    }
  }
}
"""

_TOGGLE_STAFF_FAVOURITE_MUTATION = """
mutation ($staffId: Int) {
  ToggleFavourite(staffId: $staffId) {
    staff {
      nodes { id }
    }
  }
}
"""

_ANIME_FAVOURITE_QUERY = """
query ($id: Int) {
  Media(id: $id, type: ANIME) {
    isFavourite
  }
}
"""

_CHARACTER_FAVOURITE_QUERY = """
query ($id: Int) {
  Character(id: $id) {
    isFavourite
  }
}
"""

_STAFF_FAVOURITE_QUERY = """
query ($id: Int) {
  Staff(id: $id) {
    isFavourite
  }
}
"""