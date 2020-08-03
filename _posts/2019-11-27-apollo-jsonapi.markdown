---
layout: post
title:  "Using GraphQL with JSON APIs"
date:   2019-11-27
categories: graphql jsonapi json javascript apollo
---


I've had the pleasure to work with GraphQL in some of our more recently built
applications. Developing frontend applications backed by a GraphQL API
is the most productive my team and I have ever been. The flexibility provided
lets you try out a variety of UX solutions to your problem, without any
additional work to restructure your backend.

In some of our older applications, we have APIs that range from
do-everything-at-once tangled webs to decently well-structured [JSON API spec](https://jsonapi.org/)
compliant RESTful APIs. When we decided to experiment with new workflows built on top of
one of these existing applications, we were torn between two choices:

1. Use GraphQL and get its benefits, but spend time up-front reimplementing
     convoluted that we already have verified in a JSON API.
2. Use the existing JSON API, but be stuck with managing resources on the
     client using something like Redux.

The new features would talk to a new service with a GraphQL API in
addition to the older application, so were hoping to use Apollo as our single
source of state management on the client.

As a way to jump straight to interating on the UI, I made a translation layer
from the JSON API to GraphQL with Apollo, all of which takes place on the client,
with no changes needed on the server: [Apollo Link JSON API](https://github.com/Rsullivan00/apollo-link-json-api).


## GraphQL Queries from GET requests

[`apollo-link-json-api`](https://github.com/Rsullivan00/apollo-link-json-api) lets you
write GraphQL that actually talks to a JSON API service.


```graphql
query firstAuthor {
  author @jsonapi(path: "authors/1") {
    name
  }
}
```

It will traverse relationships in related resources, and unpack them to a
structure that Apollo can use as if it were GraphQL.

```graphql
query firstAuthor {
  author @jsonapi(path: "authors/1?include=books,books.series") {
    name
    books {
      title
      series {
        title
      }
    }
  }
}
```

<!-- TODO: Add more about the JSON -> GraphQL conversion here -->
This this conversion is possible because JSON API implements some of the ideas of
GraphQL, though in a RESTful format. Namely, JSON API specifies formats for
resource relationships, and provides an interface to return related resources in
a single query. Adding the `include` parameter tells the server to return
resources traversing relationship information.


```js
// GET /authors/1?include=books,books.series
{
  data: {
    id: '1',
    type: 'authors',
    attributes: {
      name: 'John'
    }
  },
  relationships: {
    books: {
      data: [{
        id: '2',
        type: 'books'
      }]
    }
  },
  included: [{
    id: '2',
    type: 'books',
    attributes: { /* Book attributes */ },
    relationships: {
      series: {
        id: '3',
        type: 'series'
      }
    }
  }, {
    id: '3',
    type: 'series',
    attributes: { /* Series attributes */ }
  }]
}
```

Requesting an author, along with the author's books and those books' series
responds with the above. Notice that included resources are returned in a single,
flat `included` array. `type` and `id` are used to identify resources and their
relationships--Apollo Link JSON API uses those identifiers to restructure the
response into a tree structure, as if the response came from a GraphQL API.
Apollo then is happy to process the tree structure and return query results.

You can try out a demo GraphQL explorer [here](https://optimistic-wozniak-806209.netlify.app/).
Or check out the source [here](https://github.com/Rsullivan00/apollo-link-json-api).


## GraphQL Mutations from PUT/PATCH/POST/DELETE

Mutations are handled by specifying an alternate HTTP method for use in the
request. Responses are then converted in the same manner as above.
Request bodies, however, must be specified explicitly in the JSON API format--no
conversion is done there.

Here's how you could rename a book and keep your Apollo cache consistent with
the changes:

```jsx
import React from 'react'
import gql from 'graphql-tag'
import { Mutation } from 'react-apollo'

export const UPDATE_BOOK_TITLE = gql`
  mutation UpdateBookTitle($input: UpdateBookTitleInput!) {
    book(input: $input) @jsonapi(path: "/books/{args.input.data.id}", method: "PATCH") {
      title
    }
  }
`

const UpdateBookTitleButton = ({ bookId }) => (
  <Mutation
    mutation={UPDATE_BOOK_TITLE}
    update={(store, { data: { book } }) => {
      // Update your Apollo cache with result
      console.log(book.title)
    }}
  >
    {mutate => (
      <button onClick={() =>
        mutate({
          variables: {
            input: { // This part needs to be JSON API
              data: {
                id: bookId,
                type: 'books',
                attributes: { title: 'Changed title!' }
              }
            }
          },
          optimisticResponse: {
            book: {
              __typename: 'books',
              title: 'Changed title!'
            }
          }
        })
        }>
        Update your book title!
        </button>
    )}
  </Mutation>
)
```

## Lossy mappings

Converting JSON API responses to the GraphQL tree-like structure _does_ lose
some data present in JSON API. For example, servers can respond with a `meta`
field at nearly any level of the response. Let's assume our server uses
`meta` to include record counts and editable fields. A response to a request for
a list of authors would look something like this:

```js
// GET /authors?include=books
{
  meta: { record_count: 1 }, // Record counts at the top level
  data: [{
    id: '1',
    type: 'authors',
    attributes: {
      name: 'John'
    },
    meta: { editable: ['name'] } // Editable fields for authors
  },
  relationships: {
    books: {
      meta: { record_count: 1 }, // Record count for the has-many relationship
      data: [{
        id: '2',
        type: 'books'
      }]
    }
  }],
  included: [{
    id: '2',
    type: 'books',
    attributes: { /* Book attributes */ },
    meta: { editable: ['title'] } // Editable fields for books
  }]
}
```

If we want to convert that information to a GraphQL tree-structure, we now have
collisions on the `meta` key, where we would have to make an arbitrary choice
about which metadata to prefer.

```gql
query authorsWithMeta {
  authors @jsonapi(path: "authors/1?include=books") {
    // Is this top-level record count metadata or is it
    // `author` editable fields metadata?
    meta
    name
    books {
      title
      // Is this record count metadata for the `books` relationship, or is it
      // editable fields metadata for the `books` resource?
      meta
    }
  }
}
```

JSON API Apollo Link instead provides access to a verbose, lossless version of
the response tree if you add `includeJsonapi: true` to the `@jsonapi` directive.

```gql
query authorsWithMeta {
  authors @jsonapi(path: "authors/1?include=books", includeJsonapi: true) {
    graphql {
      name
      books {
        title
      }
    }
    jsonapi {
      meta {
        record_count // Authors record count
      }
      data {
        meta {
          editable // Author editable fields
        }
        relationships {
          books {
            meta {
              record_count // Books relationship record count
            }
            data {
              meta {
                editable // Book editable fields
              }
            }
          }
        }
      }
    }
  }
}
```

This is also helpful if you make use of JSON API's [`links`](https://jsonapi.org/format/#document-resource-object-links).

## Error Handling


Apollo Link JSON API currently [doesn't handle HTTP error statuses very well](https://github.com/Rsullivan00/apollo-link-json-api/issues/26)--
Apollo considers anything that's not 2XX to be a Network Error, which means that
useful HTTP statuses like `422` and their error messages are not easily
available in the query result.


This is totally fixable, but I haven't found a great solution yet. PRs are
welcome if you have a way to improve that behavior!
